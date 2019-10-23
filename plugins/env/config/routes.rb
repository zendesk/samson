# frozen_string_literal: true
Samson::Application.routes.draw do
  resources :environment_variable_groups do
    collection do
      get :preview
    end
  end
  resources :environment_variables, only: [:index, :destroy]
  resources :projects, param: :project_id do
    member do
      get :environment, action: :show, controller: 'env/environment'
      get :environment_variables_preview, action: :preview, controller: 'env/environment'
    end
  end
end
