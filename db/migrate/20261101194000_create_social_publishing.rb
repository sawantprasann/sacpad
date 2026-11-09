class CreateSocialPublishing < ActiveRecord::Migration[8.1]
  def change
    # Social publishing (brief §6.6), shaped for this app's tenant model.
    # A connected page belongs to an organization, not to one user.
    # Phase 1 publishes to Facebook Pages. provider already includes Instagram,
    # YouTube, and X so those networks do not need a later column change.
    # Integer enums match the rest of the app. Tokens are encrypted in the model.

    create_table :social_pages do |t|
      t.references :organization, null: false, foreign_key: true
      t.references :owner, null: false, foreign_key: { to_table: :users }

      # 0 facebook, 1 instagram, 2 youtube, 3 twitter
      t.integer :provider, null: false
      # 0 karyakarta, 1 official, 2 fan, 3 opposition (official/fan/opposition are v2)
      t.integer :page_type, null: false, default: 0
      # 0 active, 1 needs_reauth, 2 disconnected
      t.integer :status, null: false, default: 0

      t.string :external_id, null: false
      t.string :provider_uid
      t.string :parent_external_id
      t.string :name
      t.string :username
      t.string :url
      t.string :profile_image_url
      t.boolean :insights_available, null: false, default: false

      t.text :access_token
      t.text :refresh_token
      t.datetime :expires_at
      t.string :last_error
      t.datetime :last_error_at

      t.references :politician, null: true, foreign_key: true
      t.references :karyakarta_user, null: true, foreign_key: { to_table: :users }
      t.string :karyakarta_name_text
      t.string :karyakarta_mobile_text

      t.datetime :discarded_at
      t.references :discarded_by, null: true, foreign_key: { to_table: :users }
      t.timestamps
    end

    add_index :social_pages, [ :organization_id, :provider, :external_id ],
              unique: true,
              where: "discarded_at IS NULL",
              name: "index_social_pages_org_provider_external_kept"
    add_index :social_pages, [ :provider, :provider_uid ]
    add_index :social_pages, [ :organization_id, :status ]
    add_index :social_pages, :discarded_at

    # Short-lived OAuth payload while the user picks which Pages to keep.
    # Purged by a recurring job. Not a domain record, so no soft-delete.
    create_table :social_pending_connections do |t|
      t.references :organization, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.integer :provider, null: false
      t.string :provider_uid
      t.text :payload, null: false
      t.datetime :expires_at, null: false
      t.timestamps
    end

    add_index :social_pending_connections, :expires_at
    add_index :social_pending_connections, [ :provider, :provider_uid ]

    create_table :bulk_posts do |t|
      t.references :organization, null: false, foreign_key: true
      t.references :owner, null: false, foreign_key: { to_table: :users }

      t.string :title
      t.text :body
      # 0 draft, 1 queued, 2 completed, 3 partially_failed, 4 failed
      t.integer :status, null: false, default: 0
      # 0 explicit selection, 1 all connected pages, 2 geography filter
      t.integer :target_scope, null: false, default: 0
      t.jsonb :target_filter, null: false, default: {}
      t.datetime :video_prepared_at

      t.datetime :discarded_at
      t.references :discarded_by, null: true, foreign_key: { to_table: :users }
      t.timestamps
    end

    add_index :bulk_posts, [ :organization_id, :created_at ]
    add_index :bulk_posts, :discarded_at

    create_table :bulk_post_targets do |t|
      t.references :bulk_post, null: false, foreign_key: true
      t.references :social_page, null: false, foreign_key: true
      t.references :organization, null: false, foreign_key: true

      # 0 pending, 1 processing, 2 published, 3 failed
      t.integer :status, null: false, default: 0
      t.string :external_post_id
      t.string :permalink
      t.string :idempotency_key, null: false
      t.integer :attempts, null: false, default: 0
      t.string :error_message
      t.jsonb :provider_state, null: false, default: {}
      t.datetime :published_at
      t.timestamps
    end

    add_index :bulk_post_targets, [ :bulk_post_id, :social_page_id ], unique: true
    add_index :bulk_post_targets, :idempotency_key, unique: true
    add_index :bulk_post_targets, [ :organization_id, :status ]
    add_index :bulk_post_targets, [ :status, :published_at ]

    # One row per fetch. NULL means the platform did not return that metric.
    create_table :social_post_metrics do |t|
      t.references :bulk_post_target, null: false, foreign_key: true
      t.references :organization, null: false, foreign_key: true

      t.integer :likes_count
      t.integer :comments_count
      t.integer :shares_count
      t.integer :views_count
      t.integer :reach
      t.integer :organic_reach
      t.integer :paid_reach
      t.datetime :fetched_at, null: false
      t.timestamps
    end

    add_index :social_post_metrics, [ :bulk_post_target_id, :fetched_at ]

    # Daily page-level totals. Empty until the insights job runs.
    create_table :social_page_metric_snapshots do |t|
      t.references :social_page, null: false, foreign_key: true
      t.references :organization, null: false, foreign_key: true

      t.date :captured_on, null: false
      t.integer :followers_count
      t.integer :posts_count
      t.integer :views_count
      t.integer :organic_reach
      t.integer :paid_reach
      t.timestamps
    end

    add_index :social_page_metric_snapshots, [ :social_page_id, :captured_on ],
              unique: true,
              name: "index_social_page_snapshots_on_page_and_day"

    # Meta calls this webhook with no logged-in user, so this table is global.
    create_table :meta_deletion_requests do |t|
      t.string :confirmation_code, null: false
      t.string :provider, null: false
      t.string :provider_uid, null: false
      # 0 pending, 1 completed
      t.integer :status, null: false, default: 0
      t.timestamps
    end

    add_index :meta_deletion_requests, :confirmation_code, unique: true
    add_index :meta_deletion_requests, [ :provider, :provider_uid ]
  end
end
