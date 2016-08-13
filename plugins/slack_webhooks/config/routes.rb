# frozen_string_literal: true
Samson::Application.routes.draw do
  post '/slack_webhooks/notify', to: 'slack_webhooks#buddy_request'
end
