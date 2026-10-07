class CreateVillageLocalContacts < ActiveRecord::Migration[8.1]
  def change
    # Local people who are not system users (Story 3.3, FR29). No user_id.
    create_table :village_local_karyakartas do |t|
      t.references :village, null: false, foreign_key: true
      t.references :organization, null: false, foreign_key: true
      t.string :name, null: false
      t.string :phone
      t.text :notes
      t.datetime :discarded_at
      t.bigint :discarded_by_id
      t.timestamps
    end
    add_index :village_local_karyakartas, :discarded_at
    add_index :village_local_karyakartas, [ :organization_id, :village_id ]

    create_table :village_local_admin_contacts do |t|
      t.references :village, null: false, foreign_key: true
      t.references :organization, null: false, foreign_key: true
      t.string :name, null: false
      t.string :role_title, null: false
      t.string :phone
      t.text :notes
      t.datetime :discarded_at
      t.bigint :discarded_by_id
      t.timestamps
    end
    add_index :village_local_admin_contacts, :discarded_at
    add_index :village_local_admin_contacts, [ :organization_id, :village_id ]
  end
end
