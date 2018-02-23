# frozen_string_literal: true
class RollbarWebhook < ActiveRecord::Base
  belongs_to :stage
end
