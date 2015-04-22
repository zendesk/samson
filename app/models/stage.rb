class Stage < ActiveRecord::Base
  include Permalinkable

  has_soft_deletion default_scope: true

  belongs_to :project, touch: true

  has_many :deploys, dependent: :destroy
  has_many :webhooks, dependent: :destroy
  has_many :new_relic_applications

  has_one :lock

  has_many :stage_commands, autosave: true
  has_many :commands,
    -> { order('stage_commands.position ASC') },
    through: :stage_commands, auto_include: false

  has_and_belongs_to_many :deploy_groups

  default_scope { order(:order) }

  validates :name, presence: true, uniqueness: { scope: [:project, :deleted_at] }

  accepts_nested_attributes_for :new_relic_applications, allow_destroy: true, reject_if: :no_newrelic_name?

  attr_writer :command
  before_save :build_new_project_command

  def self.reorder(new_order)
    transaction do
      new_order.each.with_index { |stage_id, index| Stage.update stage_id.to_i, order: index.to_i }
    end
  end

  def self.build_clone(old_stage)
    new(old_stage.attributes).tap do |new_stage|
      Samson::Hooks.fire(:stage_clone, old_stage, new_stage)
      new_stage.new_relic_applications.build(old_stage.new_relic_applications.map(&:attributes))
      new_stage.command_ids = old_stage.command_ids
    end
  end

  def self.unlocked_for(user)
    where("locks.id IS NULL OR locks.user_id = ?", user.id).
    joins("LEFT OUTER JOIN locks ON \
          locks.deleted_at IS NULL AND \
          locks.stage_id = stages.id")
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

  def locked?
    !!lock && !lock.warning?
  end

  def warning?
    !!lock && lock.warning?
  end

  def locked_for?(user)
    locked? && lock.user != user
  end

  def current_release?(release)
    last_successful_deploy && last_successful_deploy.reference == release.version
  end

  def confirm_before_deploying?
    confirm
  end

  def create_deploy(options = {})
    user = options.fetch(:user)
    reference = options.fetch(:reference)

    deploys.create(reference: reference) do |deploy|
      deploy.build_job(project: project, user: user, command: command)
    end
  end

  def currently_deploying?
    current_deploy.present?
  end

  # The next stage for the project. If this is the last stage, returns nil.
  def next_stage
    stages = project.stages.to_a
    stages[stages.index(self) + 1]
  end

  def notify_email_addresses
    notify_email_address.split(";").map(&:strip)
  end

  def send_email_notifications?
    notify_email_address.present?
  end

  def command
    commands.map(&:command).join("\n")
  end

  def command_ids=(new_command_ids)
    super.tap do
      reorder_commands(new_command_ids.reject(&:blank?).map(&:to_i))
    end
  end

  def all_commands
    command_scope = project ? Command.for_project(project) : Command.global

    if command_ids.any?
      command_scope = command_scope.where(['id NOT in (?)', command_ids])
    end

    commands + command_scope
  end

  def datadog_tags
    super.to_s.split(";").map(&:strip)
  end

  def send_datadog_notifications?
    datadog_tags.any?
  end

  def send_github_notifications?
    update_github_pull_requests
  end

  def production?
    if DeployGroup.enabled?
      deploy_groups.empty? ? super : deploy_groups.any? { |deploy_group| deploy_group.environment.is_production? }
    else
      super
    end
  end

  def deploy_requires_approval?
    BuddyCheck.enabled? && production?
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

  def datadog_monitors
    datadog_monitor_ids.to_s.split(/, ?/).map { |id| DatadogMonitor.new(id) }
  end

  private

  def build_new_project_command
    return unless @command.present?

    new_command = project.commands.build(command: @command)
    stage_commands.build(command: new_command).tap do
      reorder_commands
    end
  end

  def reorder_commands(command_ids = self.command_ids)
    stage_commands.each do |stage_command|
      pos = command_ids.index(stage_command.command_id) ||
        stage_commands.length

      stage_command.position = pos
    end
  end

  def no_newrelic_name?(newrelic_attrs)
    newrelic_attrs['name'].blank?
  end

  def permalink_base
    name
  end

  def permalink_scope
    Stage.unscoped.where(project_id: project_id)
  end
end
