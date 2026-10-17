class CreateElectionsAndVoterTurnouts < ActiveRecord::Migration[8.1]
  def change
    create_table :elections do |t|
      t.references :organization, null: false, foreign_key: true
      t.string :name, null: false
      t.string :constituency_type
      t.bigint :constituency_id
      t.boolean :current, null: false, default: false
      t.timestamps
    end
    add_index :elections, :organization_id, unique: true, where: "current = true",
              name: "index_elections_one_current_per_organization"
    add_index :elections, [ :constituency_type, :constituency_id ]

    create_table :voter_turnouts do |t|
      t.references :organization, null: false, foreign_key: true
      t.references :election, null: false, foreign_key: true
      t.references :voter, null: false, foreign_key: true
      t.boolean :voted, null: false, default: false
      t.datetime :voted_at
      t.bigint :voted_by_id
      t.timestamps
    end
    add_index :voter_turnouts, [ :election_id, :voter_id ], unique: true
  end
end
