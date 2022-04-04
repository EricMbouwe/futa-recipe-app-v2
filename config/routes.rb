Rails.application.routes.draw do
  namespace :v1, defaults: {format: :json} do
    resources :recipes, only: [] do
      get :search, on: :collection
    end
  end
end

