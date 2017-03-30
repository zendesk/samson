# frozen_string_literal: true
Samson::Application.routes.draw do
  namespace :admin do
    resources :environment_variable_groups do
      collection do
        get :preview
      end
    end
    resources :environment_variables, only: [:index, :destroy]
  end
end
