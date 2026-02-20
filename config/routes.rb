Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  namespace :api do
    namespace :v1 do
      resources :rooms, only: %i[index show create] do
        get :availability, on: :member
      end

      resources :users, only: %i[index show create]

      resources :reservations, only: %i[index show create] do
        patch :cancel, on: :member
      end
    end
  end
end
