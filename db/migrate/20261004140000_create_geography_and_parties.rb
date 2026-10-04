class CreateGeographyAndParties < ActiveRecord::Migration[8.1]
  def change
    # Global, Admin-managed geography reference hierarchy (§6.3b). NOT tenant-scoped.
    create_table :states do |t|
      t.string :name, null: false
      t.timestamps
    end

    create_table :loksabhas do |t|
      t.references :state, null: false, foreign_key: true
      t.string :name, null: false
      t.timestamps
    end

    create_table :assemblies do |t|
      t.references :loksabha, null: false, foreign_key: true
      t.string :name, null: false
      t.timestamps
    end

    create_table :villages do |t|
      t.references :assembly, null: false, foreign_key: true
      t.string :name, null: false
      t.timestamps
    end

    create_table :booths do |t|
      t.references :village, null: false, foreign_key: true
      t.string :number, null: false
      t.timestamps
    end

    # Global party reference data (§3.1b). Logo via Active Storage (attached in model).
    create_table :parties do |t|
      t.string :name, null: false
      t.string :abbreviation
      t.string :color
      t.timestamps
    end
  end
end
