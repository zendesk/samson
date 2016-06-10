Samson::Application.routes.draw do
  get '/slack_webhooks/users', to: 'slack_webhooks#users'
  post '/slack_webhooks/notify', to: 'slack_webhooks#notify'
end

