# frozen_string_literal: true
class SlackWebhookThread < ActiveRecord::Base
  belongs_to :deploy
end
