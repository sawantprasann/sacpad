class CreateActivityLogs < ActiveRecord::Migration[8.1]
  def change
    # Cross-table, append-only "who did what, where" index (§7a). Also where Admin cross-org
    # access is logged (§8a). NOT tenant-scoped — it records admin cross-org entries too; it
    # carries organization_id as data.
    create_table :activity_logs do |t|
      t.references :actor, polymorphic: true, null: false   # User or Admin
      t.string     :action, null: false                      # e.g. "ticket.closed", "org.viewed"
      t.references :record, polymorphic: true, null: true
      t.bigint     :organization_id
      t.datetime   :created_at, null: false
    end
    add_index :activity_logs, :organization_id
    add_index :activity_logs, :created_at
  end
end
