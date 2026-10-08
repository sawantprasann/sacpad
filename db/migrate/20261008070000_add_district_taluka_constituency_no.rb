class AddDistrictTalukaConstituencyNo < ActiveRecord::Migration[8.1]
  def change
    create_table :districts do |t|
      t.bigint :state_id, null: false
      t.string :name, null: false
      t.timestamps
    end
    add_index :districts, :state_id
    add_foreign_key :districts, :states

    create_table :talukas do |t|
      t.bigint :district_id, null: false
      t.string :name, null: false
      t.timestamps
    end
    add_index :talukas, :district_id
    add_foreign_key :talukas, :districts

    add_column :loksabhas, :district_id, :bigint
    add_column :loksabhas, :constituency_no, :string
    add_index :loksabhas, :district_id
    add_foreign_key :loksabhas, :districts

    add_column :assemblies, :taluka_id, :bigint
    add_column :assemblies, :constituency_no, :string
    add_index :assemblies, :taluka_id
    add_foreign_key :assemblies, :talukas
  end
end
