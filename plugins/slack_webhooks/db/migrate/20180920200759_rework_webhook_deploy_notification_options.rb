# frozen_string_literal: true

class ReworkWebhookDeployNotificationOptions < ActiveRecord::Migration[5.2]
  class SlackWebhook < ActiveRecord::Base
  end

  def up
    add_column :slack_webhooks, :on_deploy_success, :boolean, default: false, null: false

    SlackWebhook.find_each do |h|
      on_deploy_success_val = !h.only_on_failure && h.after_deploy ? true : false

      h.update_columns(on_deploy_success: on_deploy_success_val, only_on_failure: h.after_deploy)
    end

    rename_column :slack_webhooks, :only_on_failure, :on_deploy_failure
    remove_column :slack_webhooks, :after_deploy
  end

  def down
    add_column :slack_webhooks, :after_deploy, :boolean, default: false, null: false
    rename_column :slack_webhooks, :on_deploy_failure, :only_on_failure

    SlackWebhook.find_each do |h|
      after_deploy_val = h.on_deploy_success || h.only_on_failure
      only_on_failure_val = after_deploy_val && !h.on_deploy_success ? true : false

      h.update_columns(after_deploy: after_deploy_val, only_on_failure: only_on_failure_val)
    end

    remove_column :slack_webhooks, :on_deploy_success
  end
end
