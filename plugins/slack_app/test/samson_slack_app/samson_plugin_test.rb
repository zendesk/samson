# frozen_string_literal: true
require_relative '../test_helper'

SingleCov.covered! unless defined?(Rake) # rake preloads all plugins

describe SamsonSlackApp do
  let(:deploy) { deploys(:succeeded_test) }
  let(:stage) { deploy.stage }

  describe 'while configured' do
    it "sends notification on before hook" do
      with_env SLACK_CLIENT_ID: 'abc', SLACK_CLIENT_SECRET: 'def' do
        SlackMessage.any_instance.expects(:deliver).twice
        Samson::Hooks.fire(:before_deploy, deploy, nil)
        Samson::Hooks.fire(:after_deploy, deploy, nil)
      end
    end
  end

  describe 'while not configured' do
    it "does not send notifications when not configured" do
      # Any attempt to deliver would trigger an unstubbed network access
      Samson::Hooks.fire(:before_deploy, deploy, nil)
      Samson::Hooks.fire(:after_deploy, deploy, nil)
    end
  end
end
