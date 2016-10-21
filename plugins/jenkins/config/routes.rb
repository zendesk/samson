# frozen_string_literal: true
Samson::Application .routes.draw do
  get '/jenkins/ping', to: 'jenkins#ping'
end
