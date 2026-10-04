class CreateVotersAndVersions < ActiveRecord::Migration[8.1]
  def change
    create_table :voters do |t|
      t.references :organization, null: false, foreign_key: true   # org-owned roll (§6.7)
      t.references :booth, null: true, foreign_key: true           # real FK (§6.7)
      # geography kept as flat text for v1 (OQ-11); only booth_id is an FK
      t.string :state
      t.string :loksabha
      t.string :assembly
      t.string :village
      # PII — encrypted at rest (NFR18). text to hold ciphertext.
      t.text :voter_id   # deterministic (loose lookup key from Ticket, §6.1)
      t.text :name
      t.text :mobile
      # Sentiment (§6.7): pleased/transit/displeased, nullable, mutable
      t.integer :sentiment_status
      t.bigint :sentiment_updated_by_id
      t.datetime :sentiment_updated_at
      t.timestamps
    end

    # Tier-1 PaperTrail custom version table for Voter (§7a) — dedicated, not a shared table.
    create_table :voter_versions do |t|
      t.string   :item_type, null: false
      t.bigint   :item_id, null: false
      t.string   :event, null: false
      t.string   :whodunnit
      t.text     :object
      t.text     :object_changes
      t.datetime :created_at
    end
    add_index :voter_versions, [ :item_type, :item_id ]
  end
end
