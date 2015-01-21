class FlowdockFlow < ActiveRecord::Base
  belongs_to :stage
  scope :notifications_enabled, -> { where(enable_notifications: true) }
end
