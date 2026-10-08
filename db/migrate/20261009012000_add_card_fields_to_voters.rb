class AddCardFieldsToVoters < ActiveRecord::Migration[8.1]
  def change
    change_table :voters, bulk: true do |t|
      t.integer :age
      t.text :house_no
      t.text :gender
    end
  end
end
