class CreateTicketCategories < ActiveRecord::Migration[8.1]
  def change
    # Global Kitchen Cabinet reference data (Story 1.1, brief §6.1) — shared across every
    # organization, Admin-managed. Intentionally NO organization_id: tickets filed under a
    # category stay org-scoped (Story 1.2), the category list does not.
    create_table :ticket_categories do |t|
      t.string  :name, null: false
      t.string  :slug, null: false
      t.boolean :active, null: false, default: true
      t.integer :display_order, null: false

      t.timestamps
    end

    add_index :ticket_categories, :slug, unique: true
    add_index :ticket_categories, :display_order
  end
end
