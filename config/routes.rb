ZendeskPusher::Application.routes.draw do
  resources :jobs, only: [] do
    member { get :execute }
  end
end
