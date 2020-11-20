# frozen_string_literal: true

Samson::Application.routes.draw do
  resources :projects, only: [] do
    namespace :rollbar_dashboards do
      resources :dashboards, only: [] do
        collection do
          get :project_dashboard
        end
      end
    end
  end

  resources :deploys, only: [] do
    namespace :rollbar_dashboards do
      resources :dashboards, only: [] do
        collection do
          get :deploy_dashboard
        end
      end
    end
  end
end
