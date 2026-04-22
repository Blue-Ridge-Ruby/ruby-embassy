Rails.application.routes.draw do
  # Health check
  get "up" => "rails/health#show", as: :rails_health_check

  # Public — magic-link auth
  resource :session, only: %i[new create destroy], controller: "sessions" do
    get  :callback, on: :collection
    post :callback, on: :collection
  end

  # Authenticated user dashboard
  get "dashboard", to: "dashboard#show", as: :dashboard

  # Admin area
  namespace :admin do
    resources :users do
      post :sync, on: :collection
    end
  end

  # Background jobs dashboard (admin-only mount inside /admin/)
  mount MissionControl::Jobs::Engine, at: "/admin/jobs"

  # Public landing page
  root "pages#home"
end
