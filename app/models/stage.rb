require 'soft_deletion'

class Stage < ActiveRecord::Base
  has_soft_deletion default_scope: true

  belongs_to :project
  has_many :deploys
  has_many :flowdock_flows

  has_many :stage_commands, autosave: true
  has_many :commands,
    -> { order('stage_commands.position ASC') },
    through: :stage_commands

  default_scope { order(:order) }

  validates :name, presence: true, uniqueness: { scope: :project }

  accepts_nested_attributes_for :flowdock_flows, allow_destroy: true, reject_if: :no_flowdock_token?

  def self.reorder(new_order)
    transaction do
      new_order.each.with_index { |stage_id, index| Stage.update stage_id.to_i, order: index }
    end
  end

  def create_deploy(options = {})
    user = options.fetch(:user)
    reference = options.fetch(:reference)

    deploys.create(reference: reference) do |deploy|
      deploy.build_job(project: project, user: user, command: command)
    end
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

  def command=(command)
    return unless command.present?

    new_command = project.commands.build(command: command)
    stage_commands.build(command: new_command).tap do
      reorder_commands
    end
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

  private

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
end
