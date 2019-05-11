# frozen_string_literal: true
Samson::Application.routes.draw do
  resources :projects do
    namespace :kubernetes do
      resources :deploy_group_roles, only: [:index] do
        collection do
          get :edit_many
          put :update_many
        end
      end
      resources :roles, except: :edit do
        collection do
          post :seed
          get :example
        end
      end
      resources :releases, only: [:index, :show]
      resources :usage_limits, only: [:index]
    end
  end

  namespace :kubernetes do
    resource :role_verification, only: [:new, :create]
    resources :clusters do
      member do
        post :seed_ecr
      end
    end
    resources :deploy_group_roles do
      collection do
        post :seed
      end
    end
    resources :usage_limits, except: [:edit]
    resources :namespaces, except: [:edit]
  end
end
