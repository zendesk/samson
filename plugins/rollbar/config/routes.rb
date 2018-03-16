# frozen_string_literal: true
Samson::Application.routes.draw do
  resources :projects do
    namespace :rollbar do
      resources :dashboards, only: [] do
        collection do
          get :project
        end
      end
    end
  end
end
