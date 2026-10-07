class CreatePrRecords < ActiveRecord::Migration[8.1]
  def change
    create_table :pr_records do |t|
      t.references :organization, null: false, foreign_key: true
      t.references :owner, null: false, foreign_key: { to_table: :users }
      t.references :pr_category, null: false, foreign_key: true
      t.references :media_platform, null: true, foreign_key: true

      t.string :record_number, null: false  # PR-{org_id}-{5-digit}
      t.string :title, null: false
      t.text :description
      t.string :url
      t.string :thumbnail_url
      t.integer :sentiment, null: false, default: 0  # 0=neutral, 1=positive, 2=negative
      t.date :published_on, null: false
      t.string :media_platform_name  # Free-text fallback if no media_platform_id (for Local-Print, Local-Electronic, Podcasts)

      t.datetime :discarded_at, index: true
      t.references :discarded_by, null: true, foreign_key: { to_table: :users }

      t.timestamps
    end

    add_index :pr_records, [:organization_id, :record_number], unique: true
  end
end
