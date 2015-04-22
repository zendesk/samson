require 'dogapi'
require 'digest/md5'

class DatadogNotification
  def initialize(deploy)
    @deploy = deploy
    @stage = @deploy.stage
  end

  def deliver
    Rails.logger.info "Sending Datadog notification..."

    status = @deploy.succeeded? ? "success" : "error"

    event = Dogapi::Event.new(body,
      msg_title: @deploy.summary,
      event_type: "deploy",
      event_object: Digest::MD5.hexdigest("#{Time.new}|#{rand}"),
      alert_type: status,
      source_type_name: "samson",
      date_happened: @deploy.updated_at,
      tags: @stage.datadog_tags + ["deploy"]
    )

    client = Dogapi::Client.new(api_key, nil, "")
    status, _ = client.emit_event(event)

    if status == "202"
      Rails.logger.info "Sent Datadog notification"
    else
      Rails.logger.info "Failed to send Datadog notification: #{status}"
    end
  end

  private

  def body
    "@#{@deploy.user.email} deployed #{@deploy.short_reference} to #{@stage.name}"
  end

  def api_key
    ENV["DATADOG_API_KEY"]
  end
end
