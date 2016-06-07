Samson::Application.routes.draw do
  resources :projects do
    namespace :kubernetes do
      resources :roles, except: :edit do
        collection do
          post :seed
        end
      end
      resources :releases, only: [:index]

      resources :tasks, except: :edit do
        collection do
          post :seed
        end
      end
      resources :jobs, only: [:new, :create, :index, :show]
      resources :streams, only: [:show]
    end
  end

  namespace :kubernetes do
    resource :role_verification, only: [:new, :create]
  end

  namespace :admin do
    namespace :kubernetes do
      resources :clusters, except: :destroy
      resources :deploy_group_roles do
        collection do
          post :seed
        end
      end
    end
  end
end
