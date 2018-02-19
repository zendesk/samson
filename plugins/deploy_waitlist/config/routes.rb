Samson::Application.routes.draw do
  post '/deploy_waitlist/add', to: 'deploy_waitlist#add'
  post '/deploy_waitlist/remove', to: 'deploy_waitlist#remove'
  post '/deploy_waitlist/change', to: 'deploy_waitlist#change'
end
