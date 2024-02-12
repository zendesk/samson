# frozen_string_literal: true
# we want know which cluster had ssl errors
require 'kubeclient'
Kubeclient::Client.prepend(
  Module.new do
    def handle_exception
      super
    rescue OpenSSL::SSL::SSLError
      $!.message << " (#{@api_endpoint})" unless $!.message.frozen?
      raise
    end
  end
)

# instrument all kube-client calls since that is the only thing using rest-client
(class << RestClient::Request; self; end).prepend(
  Module.new do
    def execute(args)
      ActiveSupport::Notifications.instrument("request.rest_client.samson", args.slice(:method, :url)) { super }
    end
  end
)
