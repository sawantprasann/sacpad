class CreatePoliceStations < ActiveRecord::Migration[8.1]
  # The villages.police_station string stays for now. A later migration drops it
  # once reads and writes use police_station_id.
  def up
    create_table :police_stations do |t|
      t.references :state, null: false, foreign_key: true
      t.string :name, null: false
      t.string :native_name
      t.timestamps
    end

    execute <<~SQL
      CREATE UNIQUE INDEX index_police_stations_on_state_id_and_lower_name
      ON police_stations (state_id, lower(name))
    SQL

    add_reference :villages, :police_station, foreign_key: true

    execute <<~SQL
      INSERT INTO police_stations (state_id, name, created_at, updated_at)
      SELECT state_id, name, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP
      FROM (
        SELECT DISTINCT ON (loksabhas.state_id, lower(btrim(villages.police_station)))
          loksabhas.state_id AS state_id,
          btrim(villages.police_station) AS name
        FROM villages
        INNER JOIN assemblies ON assemblies.id = villages.assembly_id
        INNER JOIN loksabhas ON loksabhas.id = assemblies.loksabha_id
        WHERE villages.police_station IS NOT NULL
          AND btrim(villages.police_station) <> ''
        ORDER BY loksabhas.state_id, lower(btrim(villages.police_station)), villages.id
      ) AS stations
    SQL

    execute <<~SQL
      UPDATE villages
      SET police_station_id = police_stations.id
      FROM assemblies
      INNER JOIN loksabhas ON loksabhas.id = assemblies.loksabha_id
      INNER JOIN police_stations ON police_stations.state_id = loksabhas.state_id
      WHERE assemblies.id = villages.assembly_id
        AND lower(police_stations.name) = lower(btrim(villages.police_station))
        AND villages.police_station IS NOT NULL
        AND btrim(villages.police_station) <> ''
    SQL

    backfill_native_names
  end

  def down
    remove_reference :villages, :police_station, foreign_key: true
    drop_table :police_stations
  end

  private

  # Same rule as districts: spell the name in the native script only when the
  # state has a single Lok Sabha language.
  def backfill_native_names
    rows = select_all(<<~SQL)
      SELECT police_stations.id AS id,
             police_stations.name AS name,
             loksabhas.native_locale AS native_locale
      FROM police_stations
      INNER JOIN loksabhas ON loksabhas.state_id = police_stations.state_id
      WHERE loksabhas.native_locale IS NOT NULL
        AND loksabhas.native_locale <> ''
    SQL

    rows.group_by { |row| row["id"] }.each do |id, group|
      locales = group.map { |row| row["native_locale"] }.uniq
      next unless locales.one?

      native_name = NativeScript.transliterate(group.first["name"], locales.first)
      next if native_name.blank?

      execute <<~SQL
        UPDATE police_stations
        SET native_name = #{quote(native_name)}, updated_at = CURRENT_TIMESTAMP
        WHERE id = #{quote(id)}
      SQL
    end
  end
end
