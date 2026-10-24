class AddBoothIdToUsers < ActiveRecord::Migration[8.1]
  def change
    add_reference :users, :booth, null: true, foreign_key: true
  end
end
