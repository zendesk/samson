# frozen_string_literal: true

module SamsonRollbar
  class RollbarUserInformer
    REQUEST_ENV_KEY = "rollbar.exception_uuid"
    DEFAULT_PLACEHOLDER = "<!-- ROLLBAR ERROR -->"

    class << self
      attr_accessor :user_information
      attr_accessor :user_information_placeholder
    end

    def initialize(app)
      @app = app
    end

    def call(env)
      status, headers, body = @app.call(env)

      if (replacement = self.class.user_information) && (error_uuid = env[REQUEST_ENV_KEY])
        replacement = replacement.gsub(/\{\{\s*error_uuid\s*\}\}/, error_uuid)
        body = replace_placeholder(replacement, body, headers)
        headers["Error-Id"] = error_uuid
      end
      [status, headers, body]
    end

    private

    # - body interface is .each so we cannot use anything else
    # - always call .close on the old body so it can get garbage collected if it is a File
    def replace_placeholder(replacement, body, headers)
      new_body = []
      body.each do |chunk|
        new_body << chunk.gsub(self.class.user_information_placeholder || DEFAULT_PLACEHOLDER, replacement)
      end
      headers["Content-Length"] = new_body.inject(0) { |sum, x| sum + x.bytesize }.to_s
      new_body
    ensure
      body.close if body && body.respond_to?(:close)
    end
  end
end
