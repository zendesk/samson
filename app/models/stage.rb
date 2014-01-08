class Stage < ActiveRecord::Base
  belongs_to :project
  has_many :deploys

  def send_email_notifications?
    notify_email_address.present?
  end
end
