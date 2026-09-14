Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  namespace :v1, defaults: { format: :json } do
    resources :recipes, only: [] do
      get :search, on: :collection
    end
  end
end
