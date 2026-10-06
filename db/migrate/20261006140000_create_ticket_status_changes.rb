class CreateTicketStatusChanges < ActiveRecord::Migration[8.1]
  def change
    # Tier-2 lightweight status-transition log (Story 1.4, FR53) — one append-only row per change.
    # org-scoped like every domain table (tenant-isolation layer 4).
    create_table :ticket_status_changes do |t|
      t.references :ticket, null: false, foreign_key: true
      t.references :organization, null: false, foreign_key: true
      t.references :actor, null: false, foreign_key: { to_table: :users }
      t.string :from_status
      t.string :to_status, null: false

      t.timestamps
    end
  end
end
