class RestructureVotersToGlobalWithOrgSentiments < ActiveRecord::Migration[8.1]
  def change
    # Restructure voters table: make it GLOBAL by removing organization_id
    # and removing sentiment columns (those move to voter_sentiments)
    change_table :voters do |t|
      # Remove org-scoping and sentiment columns
      t.remove :organization_id
      t.remove :sentiment_status
      t.remove :sentiment_updated_by_id
      t.remove :sentiment_updated_at

      # Split name into first_name, last_name, middle_name
      t.remove :name
      t.text :first_name      # encrypted
      t.text :last_name       # encrypted
      t.text :middle_name     # encrypted (nullable)
    end

    # Create voter_sentiments: org-scoped sentiment tracking (acts_as_tenant)
    create_table :voter_sentiments do |t|
      t.references :voter, null: false, foreign_key: true
      t.references :organization, null: false, foreign_key: true
      t.integer :sentiment_status                          # pleased/transit/displeased
      t.bigint :sentiment_updated_by_id
      t.datetime :sentiment_updated_at
      t.timestamps
    end
    add_index :voter_sentiments, [:voter_id, :organization_id], unique: true

    # Tier-1 PaperTrail custom version table for VoterSentiment audit trail
    create_table :voter_sentiment_versions do |t|
      t.string   :item_type, null: false
      t.bigint   :item_id, null: false
      t.string   :event, null: false
      t.string   :whodunnit
      t.text     :object
      t.text     :object_changes
      t.datetime :created_at
    end
    add_index :voter_sentiment_versions, [:item_type, :item_id]
  end
end
