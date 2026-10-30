class CreateCalendarEvents < ActiveRecord::Migration[8.1]
  def change
    create_table :calendar_events do |t|
      t.references :organization, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true, index: false
      t.string :title, null: false
      t.string :color, null: false, default: "primary"
      t.datetime :starts_at, null: false
      t.datetime :ends_at, null: false
      t.string :location
      t.text :notes

      t.timestamps
    end

    add_index :calendar_events, [ :user_id, :starts_at ]
  end
end
