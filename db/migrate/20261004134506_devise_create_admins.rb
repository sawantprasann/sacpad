# frozen_string_literal: true

class DeviseCreateAdmins < ActiveRecord::Migration[8.1]
  def change
    create_table :admins do |t|
      ## Identity — platform operator (NOT a User; no organization_id/parent_id/role_id)
      t.string :name, null: false, default: ""
      t.integer :tier, null: false, default: 0   # enum: full(0) / ops(1)
      t.boolean :active, null: false, default: true

      ## Database authenticatable
      t.string :email,              null: false, default: ""
      t.string :encrypted_password, null: false, default: ""

      ## Recoverable — INTENTIONALLY OMITTED for Admin (no self-service reset; out-of-band recovery)

      ## Rememberable — INTENTIONALLY OMITTED for Admin

      ## Trackable
      t.integer  :sign_in_count, default: 0, null: false
      t.datetime :current_sign_in_at
      t.datetime :last_sign_in_at
      t.string   :current_sign_in_ip
      t.string   :last_sign_in_ip

      ## Lockable (unlock_strategy: :time — lock_strategy: :failed_attempts)
      t.integer  :failed_attempts, default: 0, null: false
      t.datetime :locked_at

      t.timestamps null: false
    end

    add_index :admins, :email, unique: true
  end
end
