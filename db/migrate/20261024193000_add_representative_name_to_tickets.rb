class AddRepresentativeNameToTickets < ActiveRecord::Migration[8.1]
  def change
    add_column :tickets, :representative_name, :string
  end
end
