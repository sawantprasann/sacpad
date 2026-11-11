class SplitPrRecordEntries < ActiveRecord::Migration[8.1]
  def up
    create_table :pr_record_entries do |t|
      t.references :pr_record, null: false, foreign_key: true
      t.references :pr_category, null: false, foreign_key: true
      t.references :media_platform, foreign_key: true
      t.text :description
      t.string :url
      t.string :thumbnail_url
      t.integer :sentiment, null: false, default: 0
      t.date :published_on, null: false
      t.string :media_platform_name
      t.timestamps
    end

    add_reference :pr_record_links, :pr_record_entry, foreign_key: true, null: true
    add_reference :pr_record_outdoor_ad_counts, :pr_record_entry, foreign_key: true, null: true
    add_reference :pr_record_podcasts, :pr_record_entry, foreign_key: true, null: true, index: { unique: true }

    execute <<~SQL
      INSERT INTO pr_record_entries (
        pr_record_id, pr_category_id, media_platform_id, description, url, thumbnail_url,
        sentiment, published_on, media_platform_name, created_at, updated_at
      )
      SELECT
        id, pr_category_id, media_platform_id, description, url, thumbnail_url,
        sentiment, published_on, media_platform_name, created_at, updated_at
      FROM pr_records
    SQL

    execute <<~SQL
      UPDATE pr_record_links
      SET pr_record_entry_id = pr_record_entries.id
      FROM pr_record_entries
      WHERE pr_record_entries.pr_record_id = pr_record_links.pr_record_id
    SQL

    execute <<~SQL
      UPDATE pr_record_outdoor_ad_counts
      SET pr_record_entry_id = pr_record_entries.id
      FROM pr_record_entries
      WHERE pr_record_entries.pr_record_id = pr_record_outdoor_ad_counts.pr_record_id
    SQL

    execute <<~SQL
      UPDATE pr_record_podcasts
      SET pr_record_entry_id = pr_record_entries.id
      FROM pr_record_entries
      WHERE pr_record_entries.pr_record_id = pr_record_podcasts.pr_record_id
    SQL

    execute <<~SQL
      UPDATE active_storage_attachments
      SET record_type = 'PrRecordEntry', record_id = pr_record_entries.id
      FROM pr_record_entries
      WHERE active_storage_attachments.record_type = 'PrRecord'
        AND active_storage_attachments.name = 'attachments'
        AND active_storage_attachments.record_id = pr_record_entries.pr_record_id
    SQL

    change_column_null :pr_record_links, :pr_record_entry_id, false
    change_column_null :pr_record_outdoor_ad_counts, :pr_record_entry_id, false
    change_column_null :pr_record_podcasts, :pr_record_entry_id, false

    remove_foreign_key :pr_record_links, :pr_records
    remove_index :pr_record_links, :pr_record_id
    remove_column :pr_record_links, :pr_record_id

    remove_foreign_key :pr_record_outdoor_ad_counts, :pr_records
    remove_index :pr_record_outdoor_ad_counts, name: "idx_on_pr_record_id_outdoor_ad_type_id_5cdb583466"
    remove_column :pr_record_outdoor_ad_counts, :pr_record_id
    add_index :pr_record_outdoor_ad_counts, [ :pr_record_entry_id, :outdoor_ad_type_id ],
              unique: true, name: "idx_pr_outdoor_counts_on_entry_and_type"

    remove_foreign_key :pr_record_podcasts, :pr_records
    remove_index :pr_record_podcasts, :pr_record_id
    remove_column :pr_record_podcasts, :pr_record_id

    remove_reference :pr_records, :pr_category, foreign_key: true
    remove_reference :pr_records, :media_platform, foreign_key: true
    remove_column :pr_records, :description, :text
    remove_column :pr_records, :url, :string
    remove_column :pr_records, :thumbnail_url, :string
    remove_column :pr_records, :sentiment, :integer, null: false, default: 0
    remove_column :pr_records, :published_on, :date, null: false
    remove_column :pr_records, :media_platform_name, :string
  end

  def down
    add_reference :pr_records, :pr_category, foreign_key: true
    add_reference :pr_records, :media_platform, foreign_key: true
    add_column :pr_records, :description, :text
    add_column :pr_records, :url, :string
    add_column :pr_records, :thumbnail_url, :string
    add_column :pr_records, :sentiment, :integer, null: false, default: 0
    add_column :pr_records, :published_on, :date
    add_column :pr_records, :media_platform_name, :string

    add_reference :pr_record_links, :pr_record, foreign_key: true
    add_reference :pr_record_outdoor_ad_counts, :pr_record, foreign_key: true
    add_reference :pr_record_podcasts, :pr_record, foreign_key: true, index: { unique: true }

    execute <<~SQL
      UPDATE pr_records
      SET pr_category_id = entries.pr_category_id,
          media_platform_id = entries.media_platform_id,
          description = entries.description,
          url = entries.url,
          thumbnail_url = entries.thumbnail_url,
          sentiment = entries.sentiment,
          published_on = entries.published_on,
          media_platform_name = entries.media_platform_name
      FROM pr_record_entries AS entries
      WHERE entries.pr_record_id = pr_records.id
        AND entries.id = (
          SELECT id FROM pr_record_entries
          WHERE pr_record_id = pr_records.id
          ORDER BY id
          LIMIT 1
        )
    SQL

    execute <<~SQL
      UPDATE pr_record_links
      SET pr_record_id = pr_record_entries.pr_record_id
      FROM pr_record_entries
      WHERE pr_record_entries.id = pr_record_links.pr_record_entry_id
    SQL

    execute <<~SQL
      UPDATE pr_record_outdoor_ad_counts
      SET pr_record_id = pr_record_entries.pr_record_id
      FROM pr_record_entries
      WHERE pr_record_entries.id = pr_record_outdoor_ad_counts.pr_record_entry_id
    SQL

    execute <<~SQL
      UPDATE pr_record_podcasts
      SET pr_record_id = pr_record_entries.pr_record_id
      FROM pr_record_entries
      WHERE pr_record_entries.id = pr_record_podcasts.pr_record_entry_id
    SQL

    execute <<~SQL
      UPDATE active_storage_attachments
      SET record_type = 'PrRecord', record_id = pr_record_entries.pr_record_id
      FROM pr_record_entries
      WHERE active_storage_attachments.record_type = 'PrRecordEntry'
        AND active_storage_attachments.name = 'attachments'
        AND active_storage_attachments.record_id = pr_record_entries.id
    SQL

    change_column_null :pr_records, :pr_category_id, false
    change_column_null :pr_records, :published_on, false
    change_column_null :pr_record_links, :pr_record_id, false
    change_column_null :pr_record_outdoor_ad_counts, :pr_record_id, false
    change_column_null :pr_record_podcasts, :pr_record_id, false

    remove_index :pr_record_outdoor_ad_counts, name: "idx_pr_outdoor_counts_on_entry_and_type"
    add_index :pr_record_outdoor_ad_counts, [ :pr_record_id, :outdoor_ad_type_id ],
              unique: true, name: "idx_on_pr_record_id_outdoor_ad_type_id_5cdb583466"

    remove_reference :pr_record_links, :pr_record_entry, foreign_key: true
    remove_reference :pr_record_outdoor_ad_counts, :pr_record_entry, foreign_key: true
    remove_reference :pr_record_podcasts, :pr_record_entry, foreign_key: true
    drop_table :pr_record_entries
  end
end
