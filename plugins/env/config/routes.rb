# frozen_string_literal: true
Samson::Application.routes.draw do
  resources :environment_variable_groups do
    collection do
      get :preview
    end
  end
  resources :environment_variables, only: [:index, :update, :show, :destroy]
  resources :projects, only: [] do
    resource :environment, only: [:show], controller: 'env/environment'
  end
end
