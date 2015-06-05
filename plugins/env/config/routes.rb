Samson::Application.routes.draw do
  namespace :admin do
    resources :environment_variable_groups do
      collection do
        get :preview
      end
    end
  end
end
