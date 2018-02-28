# frozen_string_literal: true
class RollbarWebhook < ActiveRecord::Base
  belongs_to :stage
  validates :webhook_url, :access_token, :environment, presence: true
end
