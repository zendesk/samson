# frozen_string_literal: true
# ActionDispatch has an authorization method but Rack::Request does not.
# https://github.com/kolorahl/warden-doorkeeper/issues/3
module ActionDispatchPatch
  class RequestObject
    def initialize(request)
      @request = request
    end

    def authorization
      if @request.is_a?(ActionDispatch::Request)
        @authorization = @request.authorization
      elsif @request.respond_to?(:env)
        @authorization ||= @request.env['HTTP_AUTHORIZATION'] ||
          @request.env['X-HTTP_AUTHORIZATION'] ||
          @request.env['X_HTTP_AUTHORIZATION'] ||
          @request.env['REDIRECT_X_HTTP_AUTHORIZATION']
      else
        raise "Unknown session type, not ActionDispatch::Request or Rack::Request"
      end

      @authorization
    end
  end
end
