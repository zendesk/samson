# frozen_string_literal: true
class WebhookRecorder
  KEY = 'WebhookRecorder'
  NATIVE_HEADER = /^[_A-Z]+$/

  class << self
    def record(project, request:, response:, log:)
      request_info = request.env.select { |k, _v| k =~ NATIVE_HEADER }

      data = {
        request: request_info,
        request_body: request.body.read,
        status_code: response.status,
        body: response.body,
        log: log,
        time: Time.now
      }
      Rails.cache.write(key(project), data.to_json)
    end

    def read(project)
      if result = Rails.cache.read(key(project))
        JSON.load(result).with_indifferent_access
      end
    end

    private

    def key(project)
      "#{KEY}-#{project.id}"
    end
  end
end
