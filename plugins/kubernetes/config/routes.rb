Samson::Application.routes.draw do

  resources :projects do
    resources :kubernetes_releases, only: [:new, :create, :index, :show]
    resources :project_roles, only: [:new, :create, :index, :show, :edit]

    member do
      get :kubernetes, to: 'kubernetes_project#show'
    end
  end
end
