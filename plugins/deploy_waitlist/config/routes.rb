# frozen_string_literal: true
Samson::Application.routes.draw do
  post '/deploy_waitlist/add',    to: 'deploy_waitlist#add'
  post '/deploy_waitlist/remove', to: 'deploy_waitlist#remove'
  get '/deploy_waitlist', to: 'deploy_waitlist#show'
end
