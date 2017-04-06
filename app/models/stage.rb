# frozen_string_literal: true
class Stage < ActiveRecord::Base
  AUTOMATED_NAME = 'Automated Deploys'

  has_soft_deletion default_scope: true unless self < SoftDeletion::Core

  include Permalinkable
  include HasCommands

  has_paper_trail skip: [:order, :updated_at, :created_at]

  belongs_to :project, touch: true

  has_many :deploys, dependent: :destroy
  has_many :webhooks, dependent: :destroy
  has_many :outbound_webhooks, dependent: :destroy

  belongs_to :template_stage, class_name: "Stage"
  has_many :clones, class_name: "Stage", foreign_key: "template_stage_id"

  has_one :lock, as: :resource

  has_many :command_associations, autosave: true, class_name: 'StageCommand', dependent: :destroy
  has_many :commands, -> { order('stage_commands.position ASC') },
    through: :command_associations, auto_include: false

  has_many :deploy_groups_stages, dependent: :destroy
  has_many :deploy_groups, through: :deploy_groups_stages

  default_scope { order(:order) }

  validates :name, presence: true, uniqueness: { scope: [:project, :deleted_at] }

  # n emails separated by ;
  email = '([^\s;]+@[^\s;]+)'
  validates :notify_email_address, format: /\A#{email}((\s*;\s*)?#{email}?)*\z/, allow_blank: true
  validate :validate_deploy_group_selected

  before_create :ensure_ordering
  after_destroy :destroy_deploy_groups_stages
  after_destroy :destroy_stage_pipeline
  after_soft_delete :destroy_deploy_groups_stages
  after_soft_delete :destroy_stage_pipeline

  scope :cloned, -> { where.not(template_stage_id: nil) }

  def self.reset_order(new_order)
    transaction do
      new_order.each.with_index { |stage_id, index| Stage.update stage_id.to_i, order: index.to_i }
    end
  end

  def self.build_clone(old_stage)
    new(old_stage.attributes.except("id")).tap do |new_stage|
      Samson::Hooks.fire(:stage_clone, old_stage, new_stage)
      new_stage.command_ids = old_stage.command_ids
      new_stage.template_stage = old_stage
    end
  end

  def self.deployed_on_release
    where(deploy_on_release: true)
  end

  def self.where_reference_being_deployed(reference)
    joins(deploys: :job).where(
      deploys: { reference: reference },
      jobs: { status: Job::ACTIVE_STATUSES }
    )
  end

  def current_deploy
    return @current_deploy if defined?(@current_deploy)
    @current_deploy = deploys.active.first
  end

  def last_deploy
    return @last_deploy if defined?(@last_deploy)
    @last_deploy = deploys.first
  end

  def last_successful_deploy
    return @last_successful_deploy if defined?(@last_successful_deploy)
    @last_successful_deploy = deploys.successful.first
  end

  # comparing commits might be better ...
  def current_release?(release)
    last_successful_deploy&.reference == release.version
  end

  def create_deploy(user, attributes = {})
    before_command = attributes.delete(:before_command)
    deploys.create(attributes.merge(release: !no_code_deployed, project: project)) do |deploy|
      commands = before_command.to_s.dup << script
      deploy.build_job(project: project, user: user, command: commands, commit: deploy.reference)
    end
  end

  # The next stage for the project. If this is the last stage, returns nil.
  def next_stage
    stages = project.stages.to_a
    stages[stages.index(self) + 1]
  end

  def notify_email_addresses
    notify_email_address.to_s.split(/\s*;\s*/).map(&:strip)
  end

  # this logic is replicated in SQL inside of app/jobs/csv_export_job.rb#filter_deploys for report filtering
  # update the SQL query as well when editing this method
  def production?
    if DeployGroup.enabled?
      deploy_groups.empty? ? super : environments.any?(&:production?)
    else
      super
    end
  end

  def deploy_requires_approval?
    BuddyCheck.enabled? && !no_code_deployed? && production?
  end

  def automated_failure_emails(deploy)
    return if !email_committers_on_automated_deploy_failure? && static_emails_on_automated_deploy_failure.blank?
    return unless deploy.failed?
    return unless deploy.user.integration?
    last_deploy = deploys.finished_naturally.prior_to(deploy).first
    return if last_deploy.try(:failed?)

    emails = []

    # static notification
    emails.concat static_emails_on_automated_deploy_failure.to_s.split(/, ?/)

    # authors of commits after last successful deploy
    if email_committers_on_automated_deploy_failure?
      changeset = deploy.changeset_to(last_deploy)
      emails.concat changeset.commits.map(&:author_email).compact
    end

    emails.uniq.presence
  end

  # we record a version on every script change, but do not update the stage ... see Command#trigger_stage_change
  def script_updated_after?(time)
    versions.last&.created_at&.> time
  end

  # in theory this should not get called multiple times for the same state,
  # but adding a bit of extra sanity checking to make sure nothing slips in
  def record_script_change
    state_to_record = object_attrs_for_paper_trail(attributes_before_change)
    if @last_recorded_state == state_to_record
      raise "Trying to record the same state twice"
    end

    @last_recorded_state = state_to_record
    record_update true
  end

  def destroy
    mark_for_destruction
    super
  end

  def deploy_group_names
    DeployGroup.enabled? ? deploy_groups.select(:name).sort_by(&:natural_order).map(&:name) : []
  end

  def environments
    DeployGroup.enabled? ? deploy_groups.map(&:environment).uniq : []
  end

  def command_ids=(value)
    @command_ids_changed = (command_ids != value.map(&:to_i))
    super
  end

  def influencing_stage_ids
    deploy_group_ids = deploy_groups_stages.reorder(nil).pluck(:deploy_group_id)
    stage_ids = DeployGroupsStage.reorder(nil).where(deploy_group_id: deploy_group_ids).pluck('distinct stage_id')
    Stage.reorder(nil).where(id: stage_ids, project_id: project_id).pluck(:id)
  end

  private

  def permalink_base
    name
  end

  def permalink_scope
    Stage.unscoped.where(project_id: project_id)
  end

  def ensure_ordering
    return unless project
    self.order = project.stages.maximum(:order).to_i + 1
  end

  # overwrites papertrail to record script
  def object_attrs_for_paper_trail(attributes)
    super(attributes.merge('script' => script))
  end

  # DeployGroupsStage has no ids so the default dependent: :destroy fails
  def destroy_deploy_groups_stages
    DeployGroupsStage.where(stage_id: id).delete_all
  end

  def destroy_stage_pipeline
    (project.stages - [self]).each do |s|
      if s.next_stage_ids.delete(id)
        s.save(validate: false)
      end
    end
  end

  # overwrites papertrail to record when command_ids were changed but not trigger multiple versions per save
  def changed_notably?
    super || @command_ids_changed
  end

  def validate_deploy_group_selected
    if DeployGroup.enabled? && name != AUTOMATED_NAME && deploy_groups.empty?
      errors.add(:deploy_groups, "need to be selected")
    end
  end
end
