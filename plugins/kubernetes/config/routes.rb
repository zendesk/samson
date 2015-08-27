Samson::Application.routes.draw do
  resources :projects do
    resources :kubernetes_releases, only: [:new, :create, :index, :show]
    resources :kubernetes_roles, only: [:new, :create, :index, :show, :edit]

    member do
      get :kubernetes, to: 'kubernetes_project#show'
    end
  end

  resources :kubernetes_clusters, only: [:new, :create, :index, :edit, :update, :show]
end
