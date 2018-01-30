# frozen_string_literal: true
Samson::Application.routes.draw do
  resources :gcloud, only: [] do
    member do
      post :sync_build
    end
  end
end
