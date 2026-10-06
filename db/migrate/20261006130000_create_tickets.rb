class CreateTickets < ActiveRecord::Migration[8.1]
  def change
    # Kitchen Cabinet grievance record (Story 1.2, brief §6.1). First org-scoped DOMAIN model:
    # organization_id is NOT NULL + FK (tenant-isolation layer 4). Full brief field set is created
    # now so later stories add behavior, not columns — voter_id gating is 1.6, closed_at is 1.7,
    # status transitions are 1.4.
    create_table :tickets do |t|
      t.references :owner, null: false, foreign_key: { to_table: :users }
      t.references :organization, null: false, foreign_key: true
      t.references :ticket_category, null: false, foreign_key: true

      t.string   :ticket_number
      t.string   :person_name, null: false
      t.string   :village
      t.string   :mobile
      t.text     :description
      t.date     :reported_at, null: false
      t.datetime :closed_at
      t.string   :voter_id
      t.string   :nature_of_issue
      t.decimal  :reported_value, precision: 12, scale: 2
      t.integer  :status, null: false, default: 0

      t.datetime :discarded_at
      t.bigint   :discarded_by_id

      t.timestamps
    end

    add_index :tickets, :discarded_at
    add_index :tickets, [ :organization_id, :ticket_number ], unique: true
  end
end
