# frozen_string_literal: true
# we want know which cluster had ssl errors
require 'kubeclient'
Kubeclient::Client.prepend(Module.new do
  def handle_exception
    super
  rescue OpenSSL::SSL::SSLError
    $!.message << " (#{@api_endpoint})" unless $!.message.frozen?
    raise
  end
end)
