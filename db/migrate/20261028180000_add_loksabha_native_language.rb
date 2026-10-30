class AddLoksabhaNativeLanguage < ActiveRecord::Migration[8.1]
  def change
    add_column :loksabhas, :native_locale, :string
    add_column :loksabhas, :native_name, :string
    add_column :assemblies, :native_name, :string
    add_column :villages, :native_name, :string
    add_column :booths, :native_name, :string
    add_column :talukas, :native_name, :string
    add_column :districts, :native_name, :string

    add_column :voters, :native_first_name, :text
    add_column :voters, :native_middle_name, :text
    add_column :voters, :native_last_name, :text
  end
end
