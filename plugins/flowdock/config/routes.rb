Samson::Application.routes.draw do
  get '/flowdock/users', to: 'flowdock#users'
  post '/flowdock/notify', to: 'flowdock#notify'
end
