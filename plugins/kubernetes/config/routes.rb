Samson::Application.routes.draw do
  resources :projects do
    # FIXME covert into collection action
    get 'kubernetes_roles/refresh', to: 'kubernetes_roles#refresh'

    # FIXME move into kubernetes namespace
    resources :kubernetes_releases, only: [:new, :create, :index, :show]
    resources :kubernetes_roles, only: [:index, :show, :update]
    resources :kubernetes_dashboard, only: [:index]

    # FIXME make these proper resources
    member do
      get 'kubernetes', to: 'kubernetes_project#show'

      get 'kubernetes/releases', to: 'kubernetes_project#show'
      get 'kubernetes/releases/new', to: 'kubernetes_project#show'

      get 'kubernetes/roles', to: 'kubernetes_project#show'
      get 'kubernetes/roles/:id/edit', to: 'kubernetes_project#show'
      get 'kubernetes/roles/new', to: 'kubernetes_project#show'

      get 'kubernetes/dashboard', to: 'kubernetes_project#show'
    end
  end

  namespace :admin do
    namespace :kubernetes do
      resources :clusters, only: [:new, :create, :index, :edit, :update, :show]
    end
  end
end
