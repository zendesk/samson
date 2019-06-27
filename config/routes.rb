# frozen_string_literal: true
Samson::Application.routes.draw do
  root to: 'projects#index'

  resources :projects do
    resources :jobs, only: [:index, :show, :destroy]

    resources :builds, only: [:show, :index, :new, :create, :edit, :update] do
      member do
        post :build_docker_image
      end
    end

    resource :build_command, only: [:show, :update]

    resources :deploys, only: [:index, :show, :destroy] do
      collection do
        get :active
      end

      member do
        post :buddy_check
        get :changeset
      end
    end

    resources :releases, only: [:show, :index, :new, :create], id: /v(#{Samson::RELEASE_NUMBER})/

    resources :stages do
      collection do
        patch :reorder
      end

      member do
        get :clone, to: 'stages#clone'
        post :clone, to: 'stages#clone'
      end

      resources :deploys, only: [:new, :create] do
        collection do
          post :confirm
        end
      end

      resource :commit_statuses, only: [:show]
    end

    resource :changelog, only: [:show]
    resource :stars, only: [:create]
    resources :webhooks, only: [:index, :create, :update, :destroy]
    resources :outbound_webhooks, only: [:index, :create, :update, :destroy]
    resources :references, only: [:index]
    resources :user_project_roles, only: [:index]

    member do
      get :deploy_group_versions
    end
  end

  resources :user_project_roles, only: [:index, :create]
  resources :locks, only: [:index, :create, :destroy]

  resources :deploys, only: [:index] do
    collection do
      get :active
      get :active_count
    end
  end

  resources :builds, only: [:index]

  resource :profile, only: [:show, :update]

  resources :users

  resources :access_tokens, only: [:index, :new, :create, :destroy]

  resources :environments, except: [:edit]

  resources :audits, only: [:index, :show]

  resources :commands, except: [:edit]

  resources :deploy_groups do
    member do
      get :missing_config
    end

    resource :mass_rollouts, only: [:new, :create, :destroy] do
      collection do
        post :merge
        get :review_deploy
        post :deploy
      end
    end
  end

  resources :secrets, except: [:edit] do
    collection do
      get :duplicates
    end
    member do
      get :history
      post :revert
    end
  end
  resources :secret_sharing_grants, except: [:edit, :update]

  resources :users, only: [] do
    resource :user_merges, only: [:new, :create]
  end

  resources :vault_servers, except: [:edit] do
    member do
      post :sync
    end
  end

  # legacy, can be removed when it is no longer used
  delete '/api/users/:id', to: 'users#destroy'
  post '/api/projects/:project_id/builds', to: 'builds#create'
  get '/api/deploy_groups', to: 'deploy_groups#index'
  get '/api/projects/:project_id/stages/:id/deploy_groups', to: 'deploy_groups#index'
  get '/api/locks', to: 'locks#index'
  post '/api/locks', to: 'locks#create'
  delete '/api/locks/:id', to: 'locks#destroy'
  delete '/locks', to: 'locks#destroy'
  delete '/api/locks', to: 'locks#destroy'
  get '/api/projects', to: 'projects#index'
  post '/api/projects/:project_id/automated_deploys', to: 'automated_deploys#create'
  get '/api/deploys/active_count', to: 'deploys#active_count'
  get '/api/deploys/:id', to: 'deploys#show'
  get '/api/deploys', to: 'deploys#index'

  get '/auth/github/callback', to: 'sessions#github'
  get '/auth/google/callback', to: 'sessions#google'
  post '/auth/ldap/callback', to: 'sessions#ldap'
  get '/auth/gitlab/callback', to: 'sessions#gitlab'
  get '/auth/bitbucket/callback', to: 'sessions#bitbucket'
  get '/auth/failure', to: 'sessions#failure'

  get '/jobs/enabled', to: 'jobs#enabled', as: :enabled_jobs

  get '/login', to: 'sessions#new'
  get '/logout', to: 'sessions#destroy'

  resources :csv_exports, only: [:index, :new, :create, :show]
  resources :dashboards, only: [:show] do
    member do
      get :deploy_groups
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
    post "/generic/:token" => "generic#create", as: :generic_deploy
  end

  get '/ping', to: 'ping#show'
  get '/error', to: 'ping#error'

  resources :access_requests, only: [:new, :create]

  use_doorkeeper # adds oauth/* routes
  resources :oauth_test, only: [:index, :show] if %w[development test].include?(Rails.env)
end
