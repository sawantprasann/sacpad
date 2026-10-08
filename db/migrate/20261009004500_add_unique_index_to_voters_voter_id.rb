class AddUniqueIndexToVotersVoterId < ActiveRecord::Migration[8.1]
  def change
    add_index :voters, :voter_id, unique: true
  end
end
