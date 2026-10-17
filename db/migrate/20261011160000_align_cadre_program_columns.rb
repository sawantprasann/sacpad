class AlignCadreProgramColumns < ActiveRecord::Migration[8.1]
  def change
    create_table :admin_contact_roles do |t|
      t.string :name, null: false
      t.string :slug, null: false
      t.boolean :active, null: false, default: true
      t.timestamps
    end
    add_index :admin_contact_roles, :slug, unique: true

    add_reference :village_local_admin_contacts, :admin_contact_role, foreign_key: true
    add_column :village_local_karyakartas, :address, :text

    create_table :village_works do |t|
      t.references :village, null: false, foreign_key: true
      t.references :organization, null: false, foreign_key: true
      t.string :title, null: false
      t.string :concern_person, null: false
      t.decimal :nidhi_asked, precision: 12, scale: 2, null: false
      t.integer :nidhi_category, null: false
      t.string :nidhi_category_name
      t.datetime :work_order_created_at
      t.integer :status, null: false, default: 0
      t.datetime :discarded_at
      t.bigint :discarded_by_id
      t.timestamps
    end
    add_index :village_works, :discarded_at
    add_index :village_works, [ :organization_id, :village_id ]

    add_reference :media_platforms, :pr_category, foreign_key: true

    create_table :pr_record_links do |t|
      t.references :pr_record, null: false, foreign_key: true
      t.string :url, null: false
      t.string :thumbnail_url
      t.integer :position, null: false, default: 0
      t.timestamps
    end

    add_column :voters, :sr_no, :integer
    add_index :voters, :sr_no
    add_index :voters, [ :booth_id, :sr_no ]

    add_column :voter_sentiments, :voted, :boolean, null: false, default: false
    add_column :voter_sentiments, :voted_at, :datetime
    add_column :voter_sentiments, :voted_by_id, :bigint

    create_table :booth_checklist_items do |t|
      t.references :organization, null: false, foreign_key: true
      t.references :booth, null: false, foreign_key: true
      t.string :label, null: false
      t.boolean :done, null: false, default: false
      t.timestamps
    end
    add_index :booth_checklist_items, [ :organization_id, :booth_id ]
  end
end
