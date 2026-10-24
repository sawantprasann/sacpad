class CreateSupportTickets < ActiveRecord::Migration[8.1]
  def change
    create_table :support_tickets do |t|
      t.references :organization, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.string :ticket_number, null: false
      t.string :subject, null: false
      t.integer :category, null: false, default: 0
      t.integer :status, null: false, default: 0

      t.timestamps
    end
    add_index :support_tickets, [ :organization_id, :ticket_number ], unique: true
    add_index :support_tickets, [ :user_id, :updated_at ]

    create_table :support_messages do |t|
      t.references :support_ticket, null: false, foreign_key: true
      t.references :organization, null: false, foreign_key: true
      t.references :author, polymorphic: true, null: false
      t.text :body, null: false

      t.timestamps
    end
  end
end
