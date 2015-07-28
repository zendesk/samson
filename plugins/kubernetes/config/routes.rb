Samson::Application.routes.draw do

  resources :projects do
    resources :kubernetes_releases, only: [:new, :create, :index, :show]
  end
end
