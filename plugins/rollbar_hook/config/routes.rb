# frozen_string_literal: true
Samson::Application.routes.draw do
  resources :rollbar_webhooks do
    collection do
      post :test
    end
  end
end
