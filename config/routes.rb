# frozen_string_literal: true
Samson::Application.routes.draw do
  use_doorkeeper
  root to: 'projects#index'

  namespace :api do
    resources :deploys, only: [:index] do
      collection do
        get :active_count
      end
    end

    resources :deploy_groups, only: [:index]

    resources :projects, only: [:index] do
      resources :stages, only: [:index] do
        member do
          get :deploy_groups, to: 'deploy_groups#index'
        end
      end

      resources :deploys, only: [:index]
    end

    resources :stages, only: [] do
      get :deploys, to: 'deploys#index'
      post :clone, to: 'stages#clone'
    end
  end

  resources :projects, except: [:destroy] do
    resources :jobs, only: [:index, :new, :create, :show, :destroy]

    resources :macros, only: [:index, :new, :create, :edit, :update, :destroy] do
      member { post :execute }
    end

    resources :builds, only: [:show, :index, :new, :create, :edit, :update] do
      member do
        post :build_docker_image
      end
    end

    resources :deploys, only: [:index, :show, :destroy] do
      collection do
        get :active
      end

      member do
        post :buddy_check
        get :changeset
      end
    end

    resources :releases, only: [:show, :index, :new, :create]

    resources :stages do
      collection do
        patch :reorder
      end

      member do
        get :clone, to: 'stages#clone'
      end

      resources :deploys, only: [:new, :create] do
        collection do
          post :confirm
        end
      end
    end

    resource :changelog, only: [:show]
    resources :webhooks, only: [:index, :create, :destroy]
    resources :outbound_webhooks, only: [:create, :destroy]
    resource :commit_statuses, only: [:show]
    resources :references, only: [:index]

    resources :users, only: [:index, :update]

    resources :project_roles, only: [:create]

    member do
      get :deploy_group_versions
    end
  end

  resources :streams, only: [:show]
  resources :locks, only: [:create, :destroy]

  resources :deploys, only: [:index] do
    collection do
      get :active
      get :recent
      get :search
    end
  end

  resources :deploy_groups, only: [:show]

  resource :profile, only: [:show, :update]

  resources :versions, only: [:index]

  get '/auth/github/callback', to: 'sessions#github'
  get '/auth/google/callback', to: 'sessions#google'
  post '/auth/ldap/callback', to: 'sessions#ldap'
  get '/auth/gitlab/callback', to: 'sessions#gitlab'
  get '/auth/failure', to: 'sessions#failure'

  get '/jobs/enabled', to: 'jobs#enabled', as: :enabled_jobs

  get '/login', to: 'sessions#new'
  get '/logout', to: 'sessions#destroy'

  resources :csv_exports, only: [:index, :new, :create, :show]
  resources :stars, only: [:create, :destroy]
  resources :dashboards, only: [:show] do
    member do
      get :deploy_groups
    end
  end

  namespace :admin do
    resources :users, only: [:index, :show, :update, :destroy]
    resources :projects, only: [:index, :destroy]
    resources :commands, except: [:show]
    resources :secrets, except: [:show]
    resources :environments, except: [:show]
    resources :deploy_groups do
      member do
        post :deploy_all
        get :create_all_stages_preview
        post :create_all_stages
        post :merge_all_stages
      end
    end
  end

  namespace :integrations do
    post "/circleci/:token" => "circleci#create", as: :circleci_deploy
    post "/travis/:token" => "travis#create", as: :travis_deploy
    post "/semaphore/:token" => "semaphore#create", as: :semaphore_deploy
    post "/tddium/:token" => "tddium#create", as: :tddium_deploy
    post "/jenkins/:token" => "jenkins#create", as: :jenkins_deploy
    post "/buildkite/:token" => "buildkite#create", as: :buildkite_deploy
    post "/github/:token" => "github#create", as: :github_deploy
  end

  get '/ping', to: 'ping#show'

  resources :access_requests, only: [:new, :create]

  mount SseRailsEngine::Engine, at: '/streaming'
end
