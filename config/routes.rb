Samson::Application.routes.draw do
  resources :projects do
    resources :jobs, only: [:index, :new, :create, :show, :destroy]

    resources :macros, only: [:index, :new, :create, :edit, :update, :destroy] do
      member { post :execute }
    end

    resources :deploys, only: [:index, :show, :destroy] do
      collection do
        get :active
      end

      member do
        post :buddy_check
        post :pending_start
        get :changeset
      end
    end

    resources :releases, only: [:show, :index, :new, :create]

    resources :stages do
      collection do
        patch :reorder
      end

      member do
        get :new_relic, to: 'new_relic#show'
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
    resource :commit_statuses, only: [:show]
    resources :references, only: [:index]

    member do
      get :deploy_group_versions
    end
  end

  resources :streams, only: [:show]
  resources :locks, only: [:create, :destroy]

  resources :deploys, only: [] do
    collection do
      get :active
      get :recent
    end
  end

  resources :deploy_groups, only: [:show]

  resource :profile, only: [:show, :update]

  get '/auth/github/callback', to: 'sessions#github'
  get '/auth/google/callback', to: 'sessions#google'
  get '/auth/failure', to: 'sessions#failure'

  get '/jobs/enabled', to: 'jobs#enabled', as: :enabled_jobs

  get '/login', to: 'sessions#new'
  get '/logout', to: 'sessions#destroy'

  resources :stars, only: [:create, :destroy]
  resources :dashboards, only: [:show] do
    member do
      get :deploy_groups
    end
  end

  namespace :admin do
    resources :users, only: [:index, :update, :destroy]
    resource :projects, only: [:show]
    resources :commands, except: [:show]
    resources :environments, except: [:show]
    resources :deploy_groups, except: [:show]
  end

  namespace :integrations do
    post "/travis/:token" => "travis#create", as: :travis_deploy
    post "/semaphore/:token" => "semaphore#create", as: :semaphore_deploy
    post "/tddium/:token" => "tddium#create", as: :tddium_deploy
    post "/jenkins/:token" => "jenkins#create", as: :jenkins_deploy
    post "/buildkite/:token" => "buildkite#create", as: :buildkite_deploy
    post "/github/:token" => "github#create", as: :github_deploy
  end

  get '/ping', to: 'ping#show'

  mount SseRailsEngine::Engine, at: '/streaming'

  root to: 'projects#index'
end
