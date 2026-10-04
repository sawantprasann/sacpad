class CreateRolesAndPermissions < ActiveRecord::Migration[8.1]
  def change
    create_table :roles do |t|
      t.string :name, null: false
      t.string :slug, null: false
      t.boolean :is_system, null: false, default: false
      t.boolean :can_create_users, null: false, default: false
      # v1: every role is global (organization_id nil). Column exists for future per-org roles.
      t.references :organization, null: true, foreign_key: true
      t.timestamps
    end
    add_index :roles, :slug, unique: true

    create_table :role_permissions do |t|
      t.references :role, null: false, foreign_key: true
      t.integer :module_name, null: false   # enum (named module_name: `module` is a Ruby keyword)
      t.integer :access_level, null: false, default: 0
      t.timestamps
    end
    add_index :role_permissions, [ :role_id, :module_name ], unique: true
  end
end
