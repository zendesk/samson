ZendeskPusher::Application.routes.draw do
  resources :projects, except: [:index, :destroy] do
    resources :jobs, only: [:create, :show, :update]
  end

  resources :jobs, only: [:index] do
    collection do
      get :active
    end
  end

  get '/auth/:provider/callback', to: 'sessions#create'
  get '/auth/failure', to: 'sessions#failure'

  get '/login', to: 'sessions#new'
  get '/logout', to: 'sessions#destroy'

  root to: 'projects#index'
end
