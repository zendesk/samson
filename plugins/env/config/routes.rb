# frozen_string_literal: true
Samson::Application.routes.draw do
  resources :environment_variable_groups do
    collection do
      get :preview
    end
  end

  get '/external_environment_variable_groups/:id/preview',
    to: 'external_environment_variable_groups#preview', as: 'external_env_group_preview'
  resources :environment_variables, only: [:index, :destroy]
  resources :projects, only: [] do
    resource :environment, only: [:show], controller: 'env/environment'
  end
end
