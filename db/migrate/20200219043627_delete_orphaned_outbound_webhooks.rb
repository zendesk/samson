# frozen_string_literal: true

class DeleteOrphanedOutboundWebhooks < ActiveRecord::Migration[6.0]
  class OutboundWebhook < ActiveRecord::Base
  end

  class OutboundWebhookStage < ActiveRecord::Base
  end

  def up
    OutboundWebhookStage.where('outbound_webhook_id not IN (?)', OutboundWebhook.pluck(:id)).delete_all
  end

  def down
  end
end
