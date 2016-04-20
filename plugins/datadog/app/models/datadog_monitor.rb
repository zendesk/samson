require 'dogapi'

class DatadogMonitor
  API_KEY = ENV["DATADOG_API_KEY"]
  APP_KEY = ENV["DATADOG_APPLICATION_KEY"]

  attr_reader :id

  def initialize(id)
    @id = id.to_i
  end

  def status
    case response['overall_state']
    when "OK" then :pass
    when "Alert" then :fail
    else :error
    end
  end

  def name
    response['name'] || 'error'
  end

  private

  def response
    @response ||= Dogapi::Client.new(API_KEY, APP_KEY, "").get_monitor(id).last
  end
end
