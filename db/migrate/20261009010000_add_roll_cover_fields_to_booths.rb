class AddRollCoverFieldsToBooths < ActiveRecord::Migration[8.1]
  def change
    change_table :booths, bulk: true do |t|
      t.string :name
      t.string :address
      t.string :station_type
      t.string :police_station
      t.string :pin_code
    end
  end
end
