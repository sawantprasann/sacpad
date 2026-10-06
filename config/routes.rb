Rails.application.routes.draw do
  # Org-facing scope — clean, memorable root-level path (the primary, publicly-known login).
  devise_for :users, path: ""

  # Operator (platform) scope — deliberately non-obvious path, not linked from org-facing UI.
  devise_for :admins, path: "console"
  namespace :console do
    root to: "dashboard#index"
    # Organization lifecycle (Story 0.5/0.6)
    resources :organizations do
      member do
        patch :deactivate
        patch :reactivate
      end
      # Per-org Politician roster (Story 0.12)
      resources :politicians
    end
    # Global reference-data catalogs (Admin-managed, Story 0.4)
    resources :states
    resources :loksabhas
    resources :assemblies
    resources :villages
    resources :booths
    resources :parties
    # Kitchen Cabinet ticket-category catalog (Story 1.1) — global, Admin-managed
    resources :ticket_categories
    # Role & permission catalog (Story 0.8) — the only place roles are defined
    resources :roles
    # Cross-org audit log (Story 0.11)
    resources :audit_logs, only: :index
    # Platform operational health (Story 0.13)
    resource :platform_health, only: :show, controller: :platform_health
  end
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Org-facing hierarchical user management (Story 0.9)
  resources :users, only: %i[index new create show]

  # Kitchen Cabinet (Epic 1). Story 1.1 stands up only the category-filtered list target;
  # ticket capture (1.2) and the real scoped browse list (1.3) fill it in later.
  namespace :kitchen_cabinet do
    resources :tickets, only: :index
  end

  # TailAdmin component showcase / style guide (Story 0.1a)
  get "style_guide" => "home#style_guide"

  # Defines the root path route ("/")
  root "home#index"
end
