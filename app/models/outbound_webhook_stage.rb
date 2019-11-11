# frozen_string_literal: true
class OutboundWebhookStage < ActiveRecord::Base
  belongs_to :outbound_webhook, dependent: nil, inverse_of: :outbound_webhook_stages
  belongs_to :stage, dependent: nil, inverse_of: :outbound_webhook_stages

  validates :stage_id, uniqueness: {scope: :outbound_webhook_id, message: "is already connected to this webhook"}
end
