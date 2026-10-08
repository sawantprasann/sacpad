class MovePlaceFieldsToVillages < ActiveRecord::Migration[8.1]
  def up
    add_column :villages, :police_station, :string
    add_column :villages, :pin_code, :string

    execute <<~SQL
      UPDATE villages
      SET police_station = booths.police_station,
          pin_code = booths.pin_code
      FROM booths
      WHERE booths.village_id = villages.id
        AND (booths.police_station IS NOT NULL OR booths.pin_code IS NOT NULL)
    SQL

    remove_column :booths, :police_station
    remove_column :booths, :pin_code
  end

  def down
    add_column :booths, :police_station, :string
    add_column :booths, :pin_code, :string
    remove_column :villages, :police_station
    remove_column :villages, :pin_code
  end
end
