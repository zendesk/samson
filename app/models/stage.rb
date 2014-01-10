class Stage < ActiveRecord::Base
  belongs_to :project
  has_many :deploys

  has_many :stage_commands, autosave: true
  has_many :commands,
    -> { order('stage_commands.position ASC') },
    through: :stage_commands

  default_scope { order(:order) }

  def self.reorder(new_order)
    transaction do
      new_order.each.with_index { |stage_id, index| Stage.update stage_id.to_i, order: index }
    end
  end

  def send_email_notifications?
    notify_email_address.present?
  end

  def command
    commands.map(&:command).join("\n")
  end

  def command_ids=(command_ids)
    super.tap do
      reorder_commands(command_ids)
    end
  end

  def all_commands
    all_commands = commands

    if command_ids.any?
      all_commands += Command.where(['id NOT in (?)', @stage.command_ids])
    else
      all_commands += Command.all
    end

    all_commands
  end

  private

  def reorder_commands(command_ids)
    command_ids = command_ids.reject(&:blank?).map(&:to_i)
    stage_commands.each do |stage_command|
      next unless (pos = command_ids.index(stage_command.command_id))
      stage_command.position = pos
    end
  end
end
