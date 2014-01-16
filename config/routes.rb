ZendeskPusher::Application.routes.draw do
  get "streams/show"

  resources :projects, except: [:index] do
    member do
      put :reorder, as: :reorder_stages
    end

    resources :deploys, only: [:index, :new, :create, :show, :destroy] do
      member do
        post :retry
      end
    end
    resources :stages
    resources :webhooks, only: [:index, :create, :destroy]
    resources :commit_statuses, only: [:show], constraints: { id: /.+/ }
  end

  resources :deploys, only: [] do
    member do
      get :stream, to: 'streams#show'
    end

    collection do
      get :active
      get :recent
    end
  end

  get '/auth/zendesk/callback', to: 'sessions#zendesk'
  get '/auth/github/callback', to: 'sessions#github'
  get '/auth/failure', to: 'sessions#failure'

  get '/jobs/enabled', to: 'jobs#enabled', as: :enabled_jobs

  get '/login', to: 'sessions#new'
  get '/logout', to: 'sessions#destroy'

  namespace :admin do
    resource :users, only: [:show, :update]
    resource :projects, only: [:show]
    resources :commands, except: [:show]
  end

  scope :integrations do
    post "/travis/:token" => "travis#create", as: :travis_deploy
    post "/semaphore/:token" => "semaphore#create", as: :semaphore_deploy
    post "/tddium/:token" => "tddium#create", as: :tddium_deploy
  end

  root to: 'projects#index'
end
