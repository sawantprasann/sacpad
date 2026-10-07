class CreateVillageFacts < ActiveRecord::Migration[8.1]
  def change
    # Durable village facts (Story 3.2, FR28). place_type is not named `type` so Rails
    # does not treat the table as single-table inheritance.
    create_table :worship_places do |t|
      t.references :village, null: false, foreign_key: true
      t.references :organization, null: false, foreign_key: true
      t.string :name, null: false
      t.string :place_type, null: false
      t.text :notes
      t.datetime :discarded_at
      t.bigint :discarded_by_id
      t.timestamps
    end
    add_index :worship_places, :discarded_at
    add_index :worship_places, [ :organization_id, :village_id ]

    create_table :village_yatras do |t|
      t.references :village, null: false, foreign_key: true
      t.references :organization, null: false, foreign_key: true
      t.references :updated_by, foreign_key: { to_table: :users }
      t.text :notes
      t.timestamps
    end
    add_index :village_yatras, [ :village_id, :organization_id ], unique: true

    create_table :village_political_positions do |t|
      t.references :village, null: false, foreign_key: true
      t.references :organization, null: false, foreign_key: true
      t.references :party, null: false, foreign_key: true
      t.string :representative_name, null: false
      t.string :position_title, null: false
      t.date :started_at, null: false
      t.date :ended_at
      t.datetime :discarded_at
      t.bigint :discarded_by_id
      t.timestamps
    end
    add_index :village_political_positions, :discarded_at
    add_index :village_political_positions, [ :village_id, :organization_id ],
              unique: true,
              where: "ended_at IS NULL AND discarded_at IS NULL",
              name: "one_current_position_per_village_org"
  end
end
