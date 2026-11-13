class AddInvitationToUsers < ActiveRecord::Migration[8.1]
  def up
    add_column :users, :invitation_token, :string
    add_column :users, :invitation_sent_at, :datetime
    add_column :users, :invitation_accepted_at, :datetime
    add_index :users, :invitation_token, unique: true

    # Accounts created before invites were already allowed to sign in.
    execute <<~SQL.squish
      UPDATE users
      SET invitation_accepted_at = created_at
      WHERE invitation_accepted_at IS NULL
        AND invitation_token IS NULL
    SQL
  end

  def down
    remove_index :users, :invitation_token
    remove_column :users, :invitation_accepted_at
    remove_column :users, :invitation_sent_at
    remove_column :users, :invitation_token
  end
end
