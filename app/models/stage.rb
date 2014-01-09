class Stage < ActiveRecord::Base
  belongs_to :project
  has_many :deploys
  has_many :stage_commands
  has_many :commands, through: :stage_commands

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
    @command ||= commands.map(&:command).join("\n")
  end
end
