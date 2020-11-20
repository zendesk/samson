# frozen_string_literal: true
Samson::Application.routes.draw do
  resources :projects, only: [] do
    resources :stages do
      get :new_relic, to: 'new_relic#show'
    end
  end
end
