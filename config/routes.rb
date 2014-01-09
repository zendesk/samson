ZendeskPusher::Application.routes.draw do
  get "streams/show"

  resources :projects, except: [:index] do
    put '/reorder' => 'projects#reorder'
    resources :deploys, only: [:new, :create, :show, :destroy]
    resources :stages
    resources :webhooks, only: [:index, :create, :destroy]
  end

  resources :deploys, only: [:index] do
    member do
      get :stream, to: 'streams#show'
    end

    collection do
      get :active
    end
  end

  get '/auth/:provider/callback', to: 'sessions#create'
  get '/auth/failure', to: 'sessions#failure'

  get '/login', to: 'sessions#new'
  get '/logout', to: 'sessions#destroy'

  namespace :admin do
    resource :users, only: [:show, :update]
    resource :projects, only: [:show]
  end

  scope :integrations do
    post "/travis" => "travis#create"
    post "/semaphore/:token" => "semaphore#create", as: :semaphore_deploy
  end

  root to: 'projects#index'
end
