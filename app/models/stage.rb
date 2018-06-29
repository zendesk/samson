# frozen_string_literal: true
class Stage < ActiveRecord::Base
  AUTOMATED_NAME = 'Automated Deploys'

  has_soft_deletion default_scope: true unless self < SoftDeletion::Core

  include Lockable
  include Permalinkable

  audited except: [:order]

  belongs_to :project, touch: true

  has_many :deploys, dependent: :destroy
  has_many :webhooks, dependent: :destroy
  has_many :outbound_webhooks, dependent: :destroy

  belongs_to :template_stage, class_name: "Stage", optional: true
  has_many :clones, class_name: "Stage", foreign_key: "template_stage_id"

  has_one :lock, as: :resource

  has_many :stage_commands, autosave: true, dependent: :destroy
  private :stage_commands, :stage_commands= # must use ordering via script/command_ids/command_ids=

  has_many :deploy_groups_stages, dependent: :destroy
  has_many :deploy_groups, through: :deploy_groups_stages

  default_scope { order(:order) }

  validates :name, presence: true, uniqueness: {scope: [:project, :deleted_at]}

  # n emails separated by ;
  email = '([^\s;]+@[^\s;]+)'
  validates :notify_email_address, format: /\A#{email}((\s*;\s*)?#{email}?)*\z/, allow_blank: true
  validate :validate_deploy_group_selected
  validate :validate_not_auto_deploying_without_buddy

  before_create :ensure_ordering
  after_destroy :destroy_deploy_groups_stages
  after_soft_delete :destroy_deploy_groups_stages

  scope :cloned, -> { where.not(template_stage_id: nil) }

  def self.reset_order(new_order)
    transaction do
      new_order.each.with_index { |stage_id, index| Stage.update stage_id.to_i, order: index.to_i }
    end
  end

  def self.build_clone(old_stage, attributes = {})
    new(old_stage.attributes.except("id", "next_stage_ids", "is_template").merge(attributes)).tap do |new_stage|
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
      deploys: {reference: reference},
      jobs: {status: Job::ACTIVE_STATUSES}
    )
  end

  def active_deploy
    return @active_deploy if defined?(@active_deploy)
    @active_deploy = deploys.active.first
  end

  def last_deploy
    return @last_deploy if defined?(@last_deploy)
    @last_deploy = deploys.first
  end

  def last_successful_deploy
    return @last_successful_deploy if defined?(@last_successful_deploy)
    @last_successful_deploy = deploys.successful.first
  end

  # last active or successful deploy
  def deployed_or_running_deploy
    deploys.joins(:job).where("jobs.status" => Job::ACTIVE_STATUSES + ["succeeded"]).first
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
    notify_email_address.to_s.strip.split(/\s*;\s*/).map(&:strip)
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
    BuddyCheck.enabled? && !no_code_deployed? && production_for_approval?
  end
  alias_method :production_for_approval?, :production?

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

  def script
    commands.map(&:command).join("\n")
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

  def command_ids=(new_command_ids)
    new_command_ids = new_command_ids.reject(&:blank?).map(&:to_i)
    @script_was ||= script

    # ordering set here is not kept, so we have to still sort_by(&:position) when using
    self.stage_commands = new_command_ids.each_with_index.map do |command_id, index|
      stage_command = stage_commands.detect { |sc| sc.command_id == command_id } ||
        stage_commands.new(command_id: command_id)
      stage_command.position = index
      stage_command
    end
  end

  def command_ids
    stage_commands.sort_by(&:position).map(&:command_id)
  end

  def commands
    stage_commands.sort_by(&:position).map(&:command).compact
  end

  def influencing_stage_ids
    deploy_group_ids = deploy_groups_stages.reorder(nil).pluck(:deploy_group_id)
    stage_ids = DeployGroupsStage.reorder(nil).where(deploy_group_id: deploy_group_ids).
      pluck(Arel.sql('distinct stage_id'))
    Stage.reorder(nil).where(no_code_deployed: false, id: stage_ids, project_id: project_id).pluck(:id)
  end

  def direct?
    !confirm? && no_reference_selection? && !deploy_requires_approval?
  end

  # A unique name to identify this stage in the whole system. useful for log files.
  def unique_name
    "#{project.name} / #{name}"
  end

  def url
    Rails.application.routes.url_helpers.project_stage_url(project, self)
  end

  def locked_by?(lock)
    super || environment_lock?(lock) || project_lock?(lock)
  end

  def append_new_command(command)
    @script_was ||= script

    new_command = project.commands.new(command: command)
    next_position = stage_commands.map(&:position).max + 1 || 1
    created_command = stage_commands.create(command: new_command, position: next_position).command

    if created_command.persisted?
      # manually update audit
      update_script_audit
      created_command
    end
  end

  private

  def audited_changes
    super.merge(script_changes)
  end

  def script_changes
    return {} unless @script_was
    script_is = script
    return {} if script_is == @script_was
    {"script" => [@script_was, script_is]}
  end

  def update_script_audit
    write_audit(action: 'update', audited_changes: script_changes)
  end

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

  # DeployGroupsStage has no ids so the default dependent: :destroy fails
  def destroy_deploy_groups_stages
    DeployGroupsStage.where(stage_id: id).delete_all
  end

  def validate_deploy_group_selected
    if DeployGroup.enabled? && name != AUTOMATED_NAME && deploy_groups.empty?
      errors.add(:deploy_groups, "need to be selected")
    end
  end

  def validate_not_auto_deploying_without_buddy
    if deploy_on_release? && deploy_requires_approval?
      errors.add(:deploy_on_release, "cannot be used for a stage the requires approval")
    end
  end

  def environment_lock?(lock)
    lock.resource_type == "Environment" && environments.any? { |e| lock.resource_equal?(e) }
  end

  def project_lock?(lock)
    lock.resource_type == "Project" && lock.resource_equal?(project)
  end
end
