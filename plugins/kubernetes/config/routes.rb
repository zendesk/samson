# frozen_string_literal: true
Samson::Application.routes.draw do
  resources :projects do
    namespace :kubernetes do
      resources :roles, except: :edit do
        collection do
          post :seed
          get :example
        end
      end
      resources :releases, only: [:index, :show]
    end
  end

  namespace :kubernetes do
    resource :role_verification, only: [:new, :create]
  end

  namespace :admin do
    namespace :kubernetes do
      resources :clusters, except: :destroy do
        member do
          post :seed_ecr
        end
      end
      resources :deploy_group_roles do
        collection do
          post :seed
        end
      end
    end
  end
end
