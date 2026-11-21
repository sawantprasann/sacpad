class AddDetailsToAssistantMessages < ActiveRecord::Migration[8.1]
  def change
    add_column :assistant_messages, :details, :jsonb, default: {}, null: false
  end
end
