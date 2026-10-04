class CreateOrganizations < ActiveRecord::Migration[8.1]
  def change
    create_table :organizations do |t|
      t.string :name, null: false
      t.boolean :active, null: false, default: true
      t.bigint :current_party_id                       # nullable — Independent = nil (§3.1b)
      t.references :constituency, polymorphic: true, null: true  # one Loksabha OR Assembly (§3.1c)

      t.timestamps
    end
  end
end
