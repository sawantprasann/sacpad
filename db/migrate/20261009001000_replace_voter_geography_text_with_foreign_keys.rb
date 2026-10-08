class ReplaceVoterGeographyTextWithForeignKeys < ActiveRecord::Migration[8.1]
  def up
    add_reference :voters, :state, foreign_key: true
    add_reference :voters, :loksabha, foreign_key: true
    add_reference :voters, :assembly, foreign_key: true
    add_reference :voters, :village, foreign_key: true

    execute <<~SQL
      UPDATE voters
      SET village_id = booths.village_id,
          assembly_id = villages.assembly_id,
          loksabha_id = assemblies.loksabha_id,
          state_id = loksabhas.state_id
      FROM booths
      INNER JOIN villages ON villages.id = booths.village_id
      INNER JOIN assemblies ON assemblies.id = villages.assembly_id
      INNER JOIN loksabhas ON loksabhas.id = assemblies.loksabha_id
      WHERE voters.booth_id = booths.id
    SQL

    remove_column :voters, :state
    remove_column :voters, :loksabha
    remove_column :voters, :assembly
    remove_column :voters, :village
  end

  def down
    add_column :voters, :state, :string
    add_column :voters, :loksabha, :string
    add_column :voters, :assembly, :string
    add_column :voters, :village, :string

    remove_reference :voters, :village, foreign_key: true
    remove_reference :voters, :assembly, foreign_key: true
    remove_reference :voters, :loksabha, foreign_key: true
    remove_reference :voters, :state, foreign_key: true
  end
end
