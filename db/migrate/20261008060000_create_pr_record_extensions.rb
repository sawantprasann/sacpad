class CreatePrRecordExtensions < ActiveRecord::Migration[8.1]
  def change
    create_table :pr_record_outdoor_ad_counts do |t|
      t.bigint :pr_record_id, null: false
      t.bigint :outdoor_ad_type_id, null: false
      t.integer :count, null: false

      t.timestamps
    end

    add_index :pr_record_outdoor_ad_counts, [:pr_record_id, :outdoor_ad_type_id], unique: true
    add_foreign_key :pr_record_outdoor_ad_counts, :pr_records
    add_foreign_key :pr_record_outdoor_ad_counts, :outdoor_ad_types

    create_table :pr_record_podcasts do |t|
      t.bigint :pr_record_id, null: false
      t.date :recording_date, null: false

      t.timestamps
    end

    add_index :pr_record_podcasts, :pr_record_id, unique: true
    add_foreign_key :pr_record_podcasts, :pr_records
  end
end
