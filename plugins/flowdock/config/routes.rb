# frozen_string_literal: true
Samson::Application.routes.draw do
  post '/flowdock/notify', to: 'flowdock#notify'
end
