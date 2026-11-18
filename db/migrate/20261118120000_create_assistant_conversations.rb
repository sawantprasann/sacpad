class CreateAssistantConversations < ActiveRecord::Migration[8.1]
  def change
    create_table :assistant_conversations do |t|
      t.references :organization, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.string :place_type
      t.bigint :place_id
      t.string :pending_tool
      t.jsonb :pending_arguments, null: false, default: {}
      t.jsonb :pending_places, null: false, default: []
      t.timestamps
    end
    add_index :assistant_conversations, [ :place_type, :place_id ]

    create_table :assistant_messages do |t|
      t.references :organization, null: false, foreign_key: true
      t.references :assistant_conversation, null: false, foreign_key: true
      t.integer :speaker, null: false
      t.text :body, null: false
      t.string :tool_name
      t.jsonb :tool_arguments, null: false, default: {}
      t.boolean :draft, null: false, default: false
      t.string :link_path
      t.string :link_label
      t.timestamps
    end
    add_index :assistant_messages, [ :assistant_conversation_id, :id ]
  end
end
