class Stage < ActiveRecord::Base
  has_soft_deletion default_scope: true

  belongs_to :project, touch: true
  has_many :deploys
  has_many :flowdock_flows
  has_many :new_relic_applications
  has_one :lock

  has_many :stage_commands, autosave: true
  has_many :commands,
    -> { order('stage_commands.position ASC') },
    through: :stage_commands

  has_one :last_deploy, -> {
    Deploy.successful
  }, class_name: 'Deploy'

  has_one :current_deploy, -> {
    Deploy.running
  }, class_name: 'Deploy'

  default_scope { order(:order) }

  validates :name, presence: true, uniqueness: { scope: :project }

  accepts_nested_attributes_for :flowdock_flows, allow_destroy: true, reject_if: :no_flowdock_token?
  accepts_nested_attributes_for :new_relic_applications, allow_destroy: true, reject_if: :no_newrelic_name?

  attr_writer :command
  before_save :build_new_project_command

  def self.reorder(new_order)
    transaction do
      new_order.each.with_index { |stage_id, index| Stage.update stage_id.to_i, order: index }
    end
  end

  def self.unlocked
    where(locks: { id: nil }).
    joins("LEFT OUTER JOIN locks ON \
          locks.deleted_at IS NULL AND \
          locks.stage_id = stages.id")
  end

  def locked?
    lock.present?
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

  def send_flowdock_notifications?
    flowdock_flows.any?
  end

  def flowdock_tokens
    flowdock_flows.map(&:token)
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

  def no_flowdock_token?(flowdock_attrs)
    flowdock_attrs['token'].blank?
  end

  def no_newrelic_name?(newrelic_attrs)
    newrelic_attrs['name'].blank?
  end
end
