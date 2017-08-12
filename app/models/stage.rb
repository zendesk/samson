# frozen_string_literal: true
class Stage < ActiveRecord::Base
  AUTOMATED_NAME = 'Automated Deploys'

  has_soft_deletion default_scope: true unless self < SoftDeletion::Core

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

  validates :name, presence: true, uniqueness: { scope: [:project, :deleted_at] }

  # n emails separated by ;
  email = '([^\s;]+@[^\s;]+)'
  validates :notify_email_address, format: /\A#{email}((\s*;\s*)?#{email}?)*\z/, allow_blank: true
  validate :validate_deploy_group_selected

  before_create :ensure_ordering
  before_save :append_new_command
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
    BuddyCheck.enabled? && !no_code_deployed? && production_for_approval?
  end
  alias_method :production_for_approval?, :production?

  def automated_failure_emails(deploy)
    return if !email_committers_on_automated_deploy_failure? && static_emails_on_automated_deploy_failure.blank?
    return if !deploy.failed? && deploy.errored?
    return unless deploy.user.integration?
    last_deploy = deploys.finished_naturally.prior_to(deploy).first
    return if last_deploy&.failed? || last_deploy&.errored?

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

  def command=(c)
    @script_was ||= script
    @command = c
  end

  def influencing_stage_ids
    deploy_group_ids = deploy_groups_stages.reorder(nil).pluck(:deploy_group_id)
    stage_ids = DeployGroupsStage.reorder(nil).where(deploy_group_id: deploy_group_ids).pluck('distinct stage_id')
    Stage.reorder(nil).where(no_code_deployed: false, id: stage_ids, project_id: project_id).pluck(:id)
  end

  def direct?
    !confirm? && no_reference_selection? && !deploy_requires_approval?
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

  def destroy_stage_pipeline
    (project.stages - [self]).each do |s|
      if s.next_stage_ids.delete(id)
        s.save(validate: false)
      end
    end
  end

  def validate_deploy_group_selected
    if DeployGroup.enabled? && name != AUTOMATED_NAME && deploy_groups.empty?
      errors.add(:deploy_groups, "need to be selected")
    end
  end

  # has to be done after command_ids assignment is done
  def append_new_command
    return if @command.blank?
    new_command = project.commands.new(command: @command)
    previous = stage_commands.map(&:position).max || 0
    stage_commands.build(command: new_command, position: previous + 1)
  end
end
