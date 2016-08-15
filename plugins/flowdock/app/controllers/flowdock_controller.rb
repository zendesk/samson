# frozen_string_literal: true
require 'flowdock'

class FlowdockController < ApplicationController
  def notify
    @deploy = Deploy.find(params.require(:deploy_id))
    FlowdockNotification.new(@deploy).buddy_request(params.require(:message))
    head :ok
  end
end
