class AddPartRangeToAssemblies < ActiveRecord::Migration[8.1]
  def change
    change_table :assemblies, bulk: true do |t|
      t.integer :first_part
      t.integer :last_part
    end

    add_index :villages, [ :assembly_id, :name ], unique: true
    add_index :talukas, [ :district_id, :name ], unique: true
  end
end
