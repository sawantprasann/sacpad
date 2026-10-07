class AddGroundReportImports < ActiveRecord::Migration[8.1]
  def change
    # Scoped import capability (Story 3.5, FR31). Off unless Admin grants it on a role.
    add_column :roles, :can_import, :boolean, null: false, default: false

    create_table :ground_report_imports do |t|
      t.references :organization, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.integer :kind, null: false
      t.integer :status, null: false, default: 0
      t.integer :imported_count, null: false, default: 0
      t.jsonb :row_errors, null: false, default: []
      t.timestamps
    end
  end
end
