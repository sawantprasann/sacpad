class CreateMockPollResponses < ActiveRecord::Migration[8.1]
  def change
    # One row per respondent per politician (Story 3.4, FR30). The tally is computed
    # on read; this migration does not create a tally table.
    create_table :mock_poll_responses do |t|
      t.references :village, null: false, foreign_key: true
      t.references :organization, null: false, foreign_key: true
      t.references :politician, null: false, foreign_key: true
      t.references :created_by, null: false, foreign_key: { to_table: :users }
      t.string :respondent_name, null: false
      t.string :respondent_mobile
      t.integer :preference_basis, null: false
      t.boolean :vote_intent
      t.text :note
      t.datetime :discarded_at
      t.bigint :discarded_by_id
      t.timestamps
    end
    add_index :mock_poll_responses, :discarded_at
    add_index :mock_poll_responses, [ :organization_id, :village_id, :politician_id ],
              name: "index_mock_poll_responses_on_org_village_politician"
  end
end
