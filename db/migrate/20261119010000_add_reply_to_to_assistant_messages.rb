class AddReplyToToAssistantMessages < ActiveRecord::Migration[8.1]
  def change
    add_reference :assistant_messages, :reply_to, foreign_key: { to_table: :assistant_messages }, index: true
  end
end
