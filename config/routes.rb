ZendeskPusher::Application.routes.draw do
  get "streams/show"
  resources :projects, except: [:index, :destroy] do
    resources :jobs, only: [:create, :show, :update, :destroy]
    resource  :lock, only: [:new, :create, :destroy]
  end

  resources :jobs, only: [:index] do
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

  root to: 'projects#index'
end
