class DeviseCreateUsers < ActiveRecord::Migration[8.1]
  def change
    create_table :users do |t|
      ## Tenant + hierarchy + role (User is org-scoped data, but NOT acts_as_tenant:
      ## login looks up by email with no tenant context, so the account model is exempt;
      ## isolation of user *management* is via organization_id + Pundit + subtree.)
      t.references :organization, null: false, foreign_key: true
      t.references :parent, null: true, foreign_key: { to_table: :users }
      t.references :role, null: false, foreign_key: true
      t.string :name, null: false, default: ""
      t.string :phone
      t.boolean :active, null: false, default: true

      ## Database authenticatable
      t.string :email,              null: false, default: ""
      t.string :encrypted_password, null: false, default: ""

      ## Recoverable (User only — Admin has none)
      t.string   :reset_password_token
      t.datetime :reset_password_sent_at

      ## Rememberable
      t.datetime :remember_created_at

      ## Trackable
      t.integer  :sign_in_count, default: 0, null: false
      t.datetime :current_sign_in_at
      t.datetime :last_sign_in_at
      t.string   :current_sign_in_ip
      t.string   :last_sign_in_ip

      ## Lockable
      t.integer  :failed_attempts, default: 0, null: false
      t.string   :unlock_token
      t.datetime :locked_at

      t.timestamps null: false
    end

    add_index :users, :email,                unique: true
    add_index :users, :reset_password_token, unique: true
    add_index :users, :unlock_token,         unique: true
  end
end
