class MoveTalukaFromAssemblyToVillage < ActiveRecord::Migration[8.1]
  def change
    remove_foreign_key :assemblies, :talukas
    remove_index :assemblies, :taluka_id
    remove_column :assemblies, :taluka_id, :bigint

    add_column :villages, :taluka_id, :bigint
    add_index :villages, :taluka_id
    add_foreign_key :villages, :talukas
  end
end
