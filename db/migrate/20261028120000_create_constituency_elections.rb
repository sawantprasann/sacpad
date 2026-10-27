class CreateConstituencyElections < ActiveRecord::Migration[8.1]
  def change
    # Public seat history for an Assembly or a Lok Sabha. Shared by every organization
    # assigned to that constituency, so these rows have no organization_id.
    create_table :constituency_elections do |t|
      t.string :constituency_type, null: false
      t.bigint :constituency_id, null: false
      t.integer :year, null: false
      t.string :title
      t.integer :outcome, null: false
      t.references :gained_from_party, foreign_key: { to_table: :parties }, index: { name: "index_constituency_elections_on_gained_from_party_id" }
      t.decimal :swing, precision: 6, scale: 2
      t.integer :margin_votes
      t.decimal :margin_percent, precision: 5, scale: 2
      t.decimal :margin_change, precision: 6, scale: 2
      t.integer :turnout_votes
      t.decimal :turnout_percent, precision: 5, scale: 2
      t.decimal :turnout_change, precision: 6, scale: 2
      t.integer :valid_votes
      t.integer :registered_electors
      t.decimal :electors_change, precision: 6, scale: 2
      t.timestamps
    end

    add_index :constituency_elections, [ :constituency_type, :constituency_id, :year ],
              unique: true, name: "index_constituency_elections_on_constituency_and_year"

    create_table :constituency_election_candidates do |t|
      t.references :constituency_election, null: false, foreign_key: true, index: { name: "index_election_candidates_on_election_id" }
      t.references :party, null: false, foreign_key: true, index: { name: "index_election_candidates_on_party_id" }
      t.string :candidate_name, null: false
      t.integer :votes, null: false
      t.decimal :vote_percent, precision: 5, scale: 2, null: false
      t.decimal :vote_change, precision: 6, scale: 2
      t.boolean :new_contestant, null: false, default: false
      t.boolean :winner, null: false, default: false
      t.integer :position, null: false
      t.timestamps
    end
  end
end
