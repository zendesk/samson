class FlowdockFlow < ActiveRecord::Base
  belongs_to :stage
  scope :notifications_enabled, -> { where(notifications: true) }
end
