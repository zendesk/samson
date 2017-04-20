# frozen_string_literal: true
Samson::Application.routes.draw do
  post '/slack_webhooks/notify/:deploy_id', to: 'slack_webhooks#buddy_request', as: :slack_webhooks_notify
end
