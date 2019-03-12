# frozen_string_literal: true
class WebhookRecorder
  KEY = 'WebhookRecorder-v2'
  NATIVE_HEADER = /^[_A-Z]+$/.freeze
  IGNORED_HEADERS = ["QUERY_STRING", "RAW_POST_DATA"].freeze

  class << self
    # record raw request without rails magic that combines GET+POST and wraps parameters
    # to avoid duplication
    def record(project, request:, response:, log:)
      request_headers = request.env.select { |k, _v| k =~ NATIVE_HEADER && !IGNORED_HEADERS.include?(k) }
      params = request.GET.merge(request.POST) # raw params without action/controller and wrap_params
      logged_params = request.send(:parameter_filter).filter(params) # Removing passwords, etc

      data = {
        request_headers: request_headers,
        request_params: logged_params,
        response_code: response.status,
        response_body: response.body,
        log: log,
        time: Time.now
      }
      Rails.cache.write(key(project), data.to_json)
    end

    def read(project)
      if result = Rails.cache.read(key(project))
        JSON.parse(result).with_indifferent_access
      end
    end

    private

    def key(project)
      "#{KEY}-#{project.id}"
    end
  end
end
