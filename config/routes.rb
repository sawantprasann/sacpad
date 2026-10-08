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
      # Org-level Kitchen Cabinet ticket management (Story 0.16 - admin CRUD)
      resources :org_tickets, only: %i[show edit update destroy]
    end
    # Global reference-data catalogs (Admin-managed, Story 0.4)
    resources :states
    resources :districts
    resources :loksabhas
    resources :talukas
    resources :assemblies
    resources :villages
    resources :booths
    resources :parties
    # Kitchen Cabinet ticket-category catalog (Story 1.1) — global, Admin-managed
    resources :ticket_categories
    # PR catalogs (Story 4.1) — global, Admin-managed
    resources :pr_categories
    resources :media_platforms
    resources :outdoor_ad_types
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

  # Cadre Program (Epic 2). Story 2.1 is the shared base capture; detail forms (2.2) and
  # the dashboard widget / Excel export (2.3) extend this resource.
  namespace :cadre_program do
    resources :activities, only: %i[index new create show]
  end

  # Ground Reports (Epic 3). Story 3.1 is the village report and its testimonials.
  namespace :ground_reports do
    resources :villages, only: %i[index show] do
      resources :reports, only: %i[new create show] do
        resources :testimonials, only: :create
      end
      resources :worship_places, only: :create
      resource :yatra, only: :update, controller: "yatra"
      resources :political_positions, only: :create
      resources :local_karyakartas, only: :create
      resources :local_admin_contacts, only: :create
      resources :mock_poll_responses, only: :create
    end
    resources :imports, only: %i[new create show]
  end

  # Kitchen Cabinet (Epic 1). Story 1.1 stands up only the category-filtered list target;
  # ticket capture (1.2) and the real scoped browse list (1.3) fill it in later.
  namespace :kitchen_cabinet do
    resources :tickets, only: %i[index new create show edit update] do
      member do
        patch :status
        patch :voter
      end
      resources :follow_ups, only: :create
      resource :closure, only: %i[new create]  # two-step closure + voter-sentiment (Story 1.7)
    end
  end

  # PR Records (Epic 4). Story 4.2 captures media coverage; Story 4.3 adds category-specific details.
  resources :pr_records, only: %i[index new create show edit update]

  # Defines the root path route ("/")
  root "home#index"
end
