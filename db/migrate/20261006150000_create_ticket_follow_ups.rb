class CreateTicketFollowUps < ActiveRecord::Migration[8.1]
  def change
    # Per-ticket follow-up action log (Story 1.5, FR23) — append-only, timestamped, attributed,
    # optional attachment (Active Storage). Org-scoped like every domain table.
    create_table :ticket_follow_ups do |t|
      t.references :ticket, null: false, foreign_key: true
      t.references :organization, null: false, foreign_key: true
      t.references :created_by, null: false, foreign_key: { to_table: :users }
      t.text :note, null: false

      t.timestamps
    end
  end
end
