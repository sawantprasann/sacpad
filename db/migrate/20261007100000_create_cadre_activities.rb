class CreateCadreActivities < ActiveRecord::Migration[8.1]
  def change
    # Cadre Program base row (Story 2.1, brief §6.2). organization_id is NOT NULL + FK
    # (tenant-isolation layer 4). Detail tables are Story 2.2; this table is the shared base.
    create_table :cadre_activities do |t|
      t.references :owner, null: false, foreign_key: { to_table: :users }
      t.references :organization, null: false, foreign_key: true

      t.integer :category, null: false
      t.text    :impact_notes

      t.datetime :discarded_at
      t.bigint   :discarded_by_id

      t.timestamps
    end

    add_index :cadre_activities, :discarded_at
    add_index :cadre_activities, :category
    add_index :cadre_activities, [ :organization_id, :owner_id ]
  end
end
