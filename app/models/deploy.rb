# frozen_string_literal: true
class Deploy < ActiveRecord::Base
  has_soft_deletion default_scope: true

  belongs_to :stage, touch: true
  belongs_to :build, optional: true
  belongs_to :project
  belongs_to :job
  belongs_to :buddy, -> { unscope(where: "deleted_at") }, class_name: 'User', optional: true

  default_scope { order(id: :desc) }

  validates_presence_of :reference
  validate :validate_stage_is_unlocked, on: :create
  validate :validate_stage_uses_deploy_groups_properly, on: :create

  delegate :started_by?, :can_be_cancelled_by?, :cancel, :status, :user, :output, to: :job
  delegate :active?, :pending?, :running?, :cancelling?, :cancelled?, :succeeded?, to: :job
  delegate :finished?, :errored?, :failed?, to: :job
  delegate :production?, to: :stage

  before_validation :trim_reference

  attr_accessor :skip_deploy_group_validation

  SUMMARY_ACTION = {
    "pending"    => "is about to deploy",
    "running"    => "is deploying",
    "succeeded"  => "deployed",
    "cancelled"  => "cancelled",
    "cancelling" => "is cancelling",
    "failed"     => "failed to deploy",
    "errored"    => "encountered an error deploying"
  }.freeze

  def cache_key
    [super, commit]
  end

  # queue deploys on stages that cannot execute in parallel
  def job_execution_queue_name
    "stage-#{stage.id}" unless stage.run_in_parallel
  end

  # job has almost identical code, keep it in sync
  def summary(show_project: false)
    project_name = " #{project&.name}" if show_project
    deploy_details = "#{short_reference} to#{project_name} #{stage&.name}"
    if ["cancelled", "cancelling"].include?(status)
      canceller_name = job.canceller&.name || "Samson"
      "#{canceller_name} #{summary_action} #{job.user.name}`s deploy#{deploy_buddy} of #{deploy_details}"
    else
      "#{job.user.name}#{deploy_buddy} #{summary_action} #{deploy_details}"
    end
  end

  # same as summary but without mentioning the user since it will be in the UI close by
  def summary_for_timeline
    if ["cancelling", "cancelled", "errored"].include?(status)
      "#{short_reference} deploy to #{stage&.name} is #{status}"
    else
      "#{short_reference}#{' was' if job.succeeded?} #{summary_action} to #{stage&.name}"
    end
  end

  def commit
    job.try(:commit).presence || reference
  end

  def short_reference
    if reference =~ Build::SHA1_REGEX
      reference[0...7]
    else
      reference
    end
  end

  def previous_deploy
    stage.deploys.prior_to(self).first
  end

  def previous_successful_deploy
    stage.deploys.successful.prior_to(self).first
  end

  def changeset
    @changeset ||= changeset_to(previous_successful_deploy)
  end

  def changeset_to(other)
    Changeset.new(project.repository_path, other.try(:commit), commit)
  end

  def production
    stage&.production?
  end

  def buddy
    super || NullUser.new(buddy_id) if buddy_id
  end

  # user clicked "Bypass" button to bypass deploy approval
  def bypassed_approval?
    stage.deploy_requires_approval? && buddy == user
  end

  def waiting_for_buddy?
    pending? && stage.deploy_requires_approval? && !buddy
  end

  def confirm_buddy!(buddy)
    update_attributes!(buddy: buddy, started_at: Time.now)
    start
  end

  def start_time
    started_at || created_at
  end

  def duration
    updated_at - start_time
  end

  def self.start_deploys_waiting_for_restart!
    pending.reorder(nil).reject(&:waiting_for_buddy?).each do |deploy|
      deploy.touch # HACK: refresh is immediate with update
      deploy.send :start
    end
  end

  def self.active
    includes(:job).where(jobs: { status: Job::ACTIVE_STATUSES })
  end

  def self.active_count
    Rails.cache.fetch('deploy_active_count', expires_in: 10.seconds) do
      active.count
    end
  end

  def self.pending
    joins(:job).where(jobs: { status: 'pending' })
  end

  def self.running
    joins(:job).where(jobs: { status: 'running' })
  end

  def self.successful
    joins(:job).where(jobs: { status: 'succeeded' })
  end

  def self.finished_naturally
    joins(:job).where(jobs: { status: ['succeeded', 'failed'] })
  end

  def self.prior_to(deploy)
    deploy.persisted? ? where("#{table_name}.id < ?", deploy.id) : all
  end

  def self.expired
    threshold = BuddyCheck.time_limit.ago
    stale = where(buddy_id: nil).joins(:job).where(jobs: { status: 'pending'}).where("jobs.created_at < ?", threshold)
    stale.select(&:waiting_for_buddy?)
  end

  def self.for_user(user)
    joins(:job).where(jobs: { user: user })
  end

  def self.last_deploys_for_projects
    deploy_ids = group(:project_id).reorder("max(deploys.id)").pluck('max(deploys.id)')
    where(id: deploy_ids) # extra select so we get all columns from the correct deploy without group functions
  end

  def buddy_name
    user.id == buddy_id ? "bypassed" : buddy.try(:name)
  end

  def buddy_email
    user.id == buddy_id ? "bypassed" : buddy.try(:email)
  end

  def url
    Rails.application.routes.url_helpers.project_deploy_url(project, self)
  end

  def self.csv_header
    [
      "Deploy Number", "Project Name", "Deploy Summary", "Deploy Commit", "Deploy Status", "Deploy Updated",
      "Deploy Created", "Deployer Name", "Deployer Email", "Buddy Name", "Buddy Email", "Stage Name",
      "Production Flag", "Code deployed", "Project Deleted On", "Deploy Groups"
    ]
  end

  def as_csv
    [
      id, project.name, summary, commit, job.status, updated_at, start_time, user.try(:name), user.try(:email),
      buddy_name, buddy_email, stage.name, stage.production?, !stage.no_code_deployed, project.deleted_at,
      stage.deploy_group_names.join('|')
    ]
  end

  private

  def start
    DeployService.new(user).confirm_deploy(self)
  end

  def summary_action
    SUMMARY_ACTION.fetch(status)
  end

  def validate_stage_is_unlocked
    errors.add(:stage, 'is locked') if Lock.locked_for?(stage, user)
  end

  # commands and deploy groups can change via many different paths,
  # so we validate once a user actually tries to execute the command
  def validate_stage_uses_deploy_groups_properly
    return unless DeployGroup.enabled?
    return if skip_deploy_group_validation
    return if stage.deploy_groups.any?
    return unless stage.script.include?("$DEPLOY_GROUPS")
    errors.add(
      :stage,
      "contains at least one command using the $DEPLOY_GROUPS environment variable," \
      " but there are no Deploy Groups associated with this stage."
    )
  end

  def deploy_buddy
    return unless stage.deploy_requires_approval?

    if buddy.nil? && pending?
      " (waiting for a buddy)"
    elsif buddy.nil? || job.user_id == buddy_id
      " (without a buddy)"
    else
      " (with #{buddy.name})"
    end
  end

  def trim_reference
    self.reference = reference.strip if reference.present?
  end
end
