class CreatePrCatalogs < ActiveRecord::Migration[8.1]
  def change
    # PR Categories: fixed 6-category taxonomy for media coverage
    create_table :pr_categories do |t|
      t.string :name, null: false
      t.string :slug, null: false
      t.integer :display_order, null: false, default: 0
      t.boolean :active, null: false, default: true
      t.timestamps
    end
    add_index :pr_categories, :slug, unique: true

    # Media Platforms: extensible list (TV, Newspaper, Radio, Website, etc.)
    create_table :media_platforms do |t|
      t.string :name, null: false
      t.string :slug, null: false
      t.boolean :active, null: false, default: true
      t.timestamps
    end
    add_index :media_platforms, :slug, unique: true

    # Outdoor Ad Types: extensible list for Outdoor Media records (Billboard, Bus Shelter, etc.)
    create_table :outdoor_ad_types do |t|
      t.string :name, null: false
      t.string :slug, null: false
      t.boolean :active, null: false, default: true
      t.timestamps
    end
    add_index :outdoor_ad_types, :slug, unique: true
  end
end
