class AddCdToStateAndDistrict < ActiveRecord::Migration[8.1]
  def change
    add_column :states, :cd, :string
    add_column :districts, :cd, :string
  end
end
