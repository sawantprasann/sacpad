class CreatePartyMembershipsAndAdminOrganizations < ActiveRecord::Migration[8.1]
  def change
    # History-preserving party affiliation per organization (§3.1b).
    create_table :party_memberships do |t|
      t.references :organization, null: false, foreign_key: true
      t.references :party, null: false, foreign_key: true
      t.datetime :started_at, null: false
      t.datetime :ended_at   # nil = currently active
      t.timestamps
    end

    # Scopes an ops-tier Admin to specific organizations (§3.0).
    create_table :admin_organizations do |t|
      t.references :admin, null: false, foreign_key: true
      t.references :organization, null: false, foreign_key: true
      t.timestamps
    end
    add_index :admin_organizations, [ :admin_id, :organization_id ], unique: true
  end
end
