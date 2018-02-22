# frozen_string_literal: true
Samson::Application.routes.draw do
  resources :gcloud, only: [] do
    member do
      post :sync_build
    end
  end
  resources :gke_clusters, only: [:new, :create]
end
