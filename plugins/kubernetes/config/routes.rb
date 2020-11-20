# frozen_string_literal: true
Samson::Application.routes.draw do
  resources :projects, only: [] do
    namespace :kubernetes do
      resources :deploy_group_roles do
        collection do
          post :seed
          get :edit_many
          put :update_many
        end
      end
      resources :stages do
        member do
          get :manifest_preview
        end
      end
      resources :roles, except: :edit do
        collection do
          post :seed
          get :example
        end
      end
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
    resources :deploy_group_roles, only: [:index]
    resources :usage_limits, except: [:edit]
    resources :namespaces, except: [:edit] do
      member do
        post :sync
      end
      collection do
        get :preview
        post :sync_all
      end
    end
  end
end
