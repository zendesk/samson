# frozen_string_literal: true
class FlowdockFlow < ActiveRecord::Base
  belongs_to :stage
  scope :enabled, -> { where(enabled: true) }
end
