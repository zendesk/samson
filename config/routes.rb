ZendeskPusher::Application.routes.draw do
  resources :projects, only: [:edit, :show] do
    resources :jobs, only: [:create, :show, :update]
  end

  get '/auth/:provider/callback', to: 'sessions#create'
  get '/auth/failure', to: 'sessions#failure'

  get '/login', to: 'sessions#new'
  get '/logout', to: 'sessions#destroy'

  root to: 'projects#index'
end
