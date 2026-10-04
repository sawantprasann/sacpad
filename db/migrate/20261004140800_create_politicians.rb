class CreatePoliticians < ActiveRecord::Migration[8.1]
  def change
    create_table :politicians do |t|
      t.references :organization, null: false, foreign_key: true
      t.string :name, null: false
      t.references :party, null: true, foreign_key: true   # snapshot (not history-preserving, §6.3a)
      t.boolean :is_own_politician, null: false, default: false
      t.datetime :discarded_at
      t.bigint :discarded_by_id
      t.timestamps
    end
    add_index :politicians, :discarded_at
    # Exactly one own-candidate per organization (§6.3a).
    add_index :politicians, :organization_id, unique: true,
      where: "is_own_politician = true", name: "one_own_politician_per_org"
  end
end
