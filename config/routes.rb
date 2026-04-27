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
    root "dashboard#show"
    resources :users do
      post :sync, on: :collection
    end
    resources :schedule_items do
      resources :lightning_talk_signups, only: %i[index create update destroy] do
        collection { patch :reorder }
      end
    end
    resources :volunteers, only: %i[index show]
    resources :volunteer_slots, only: %i[index show]
    resources :volunteer_signups, only: %i[create destroy]
    resources :embassy_questions
    resources :notary_profiles
    resources :embassy_applications, only: %i[index show] do
      member do
        patch :mark_received
        patch :unmark_received
      end
      collection do
        get :delivered
      end
    end
    resource :embassy_blank_pdfs, only: %i[new create]
  end

  # Background jobs dashboard (admin-only mount inside /admin/)
  mount MissionControl::Jobs::Engine, at: "/admin/jobs"

  # Public landing page
  root "pages#home"

  get "schedule", to: "schedule#index"
  get "plan", to: "plan#index"

  resources :plan_items, only: %i[create update destroy]
  resources :schedule_items, only: %i[new create edit update] do
    resource :lightning_talk_signup, only: %i[create edit update]
    resources :meal_spots, only: %i[index new create edit update] do
      resources :rsvps, only: %i[create destroy], controller: "meal_spot_rsvps"
    end
  end

  # Embassy booking + application — attendee-facing mockup
  resources :embassy_bookings, only: %i[new create]
  resources :embassy_applications, only: %i[new create show edit update]

  # Branded error pages. Reached via config.exceptions_app = self.routes.
  match "/404", to: "errors#not_found",             via: :all
  match "/422", to: "errors#unprocessable_content", via: :all
  match "/500", to: "errors#internal_server_error", via: :all
end
