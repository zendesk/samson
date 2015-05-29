Samson::Application.routes.draw do
  namespace :admin do
    resources :environment_variable_groups
  end
end
