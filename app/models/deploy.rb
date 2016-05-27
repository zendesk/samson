class Deploy < ActiveRecord::Base
  has_soft_deletion default_scope: true

  belongs_to :stage, touch: true
  belongs_to :build
  belongs_to :job
  belongs_to :buddy, class_name: 'User'

  default_scope { order(created_at: :desc, id: :desc) }

  validates_presence_of :reference
  validate :validate_stage_is_unlocked, on: :create
  validate :validate_stage_uses_deploy_groups_properly, on: :create

  delegate :started_by?, :can_be_stopped_by?, :stop!, :status, :user, :output, to: :job
  delegate :active?, :pending?, :running?, :cancelling?, :cancelled?, :succeeded?, to: :job
  delegate :finished?, :errored?, :failed?, to: :job
  delegate :production?, :project, to: :stage

  before_validation :trim_reference

  def cache_key
    [super, commit]
  end

  def summary
    "#{job.user.name} #{deploy_buddy} #{summary_action} #{short_reference} to #{stage.name}"
  end

  def summary_for_process
    t = (Time.now.to_i - start_time.to_i)
    "ProcessID: #{job.pid} Running: #{t} seconds"
  end

  def summary_for_timeline
    "#{short_reference}#{' was' if job.succeeded?} #{summary_action} to #{stage.name}"
  end

  def summary_for_email
    "#{job.user.name} #{summary_action} #{project.name} to #{stage.name} (#{reference})"
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
    stage.deploys.successful.prior_to(self).first
  end

  def changeset
    @changeset ||= changeset_to(previous_deploy)
  end

  def changeset_to(other)
    Changeset.new(project.github_repo, other.try(:commit), commit)
  end

  def production
    stage.production?
  end

  def buddy
    super || NullUser.new(buddy_id) if buddy_id
  end

  def bypassed_approval?
    stage.deploy_requires_approval? && buddy == user
  end

  def waiting_for_buddy?
    pending? && stage.deploy_requires_approval? && !buddy
  end

  def confirm_buddy!(buddy)
    update_attributes!(buddy: buddy, started_at: Time.now)
    DeployService.new(user).confirm_deploy!(self)
  end

  def start_time
    started_at || created_at
  end

  def pending_start!
    touch # HACK: refresh is immediate with update
    DeployService.new(user).confirm_deploy!(self)
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
    threshold = BuddyCheck.time_limit.minutes.ago
    joins(:job).where(jobs: { status: 'pending'}).where("jobs.created_at < ?", threshold)
  end

  def buddy_name
    user.id == buddy_id ? "bypassed" : buddy.try(:name)
  end

  def buddy_email
    user.id == buddy_id ? "bypassed" : buddy.try(:email)
  end

  def url
    AppRoutes.url_helpers.project_deploy_url(project, self)
  end

  private

  def summary_action
    if pending?
      "is about to deploy"
    elsif running?
      "is deploying"
    elsif cancelling?
      "is cancelling a deploy"
    elsif cancelled?
      "cancelled a deploy"
    elsif succeeded?
      "deployed"
    elsif failed?
      "failed to deploy"
    elsif errored?
      "encountered an error deploying"
    end
  end

  def validate_stage_is_unlocked
    if stage.locked_for?(user) || Lock.global.exists?
      errors.add(:stage, 'is locked')
    end
  end

  # commands and deploy groups can change via many different paths,
  # so we validate once a user actually tries to execute the command
  def validate_stage_uses_deploy_groups_properly
    if DeployGroup.enabled? && stage.deploy_groups.none? && stage.script.include?("$DEPLOY_GROUPS")
      errors.add(
        :stage,
        "contains at least one command using the $DEPLOY_GROUPS environment variable," \
        " but there are no Deploy Groups associated with this stage."
      )
    end
  end

  def deploy_buddy
    return unless stage.deploy_requires_approval?

    if buddy.nil? && pending?
      "(waiting for a buddy)"
    elsif buddy.nil? || job.user_id == buddy_id
      "(without a buddy)"
    else
      "(with #{buddy.name})"
    end
  end

  def trim_reference
    reference.strip! if reference.presence
  end
end
