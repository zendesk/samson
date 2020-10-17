# frozen_string_literal: true
Samson::Application.routes.draw do
  get '/slack_app/oauth', to: 'slack_app#oauth'
  post '/slack_app/command', to: 'slack_app#command'
  post '/slack_app/interact', to: 'slack_app#interact'
end
