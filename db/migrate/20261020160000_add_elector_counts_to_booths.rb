class AddElectorCountsToBooths < ActiveRecord::Migration[8.1]
  def change
    change_table :booths, bulk: true do |t|
      t.integer :male_electors
      t.integer :female_electors
      t.integer :other_electors
    end
  end
end
