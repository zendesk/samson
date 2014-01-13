class Stage < ActiveRecord::Base
  belongs_to :project
  has_many :deploys

  default_scope { order(:order) }

  def self.reorder(new_order)
    transaction do
      new_order.each.with_index { |stage_id, index| Stage.update stage_id.to_i, order: index }
    end
  end

  def send_email_notifications?
    notify_email_address.present?
  end

  def latest_deploys
    deploys.latest
  end

end
