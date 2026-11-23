class CreateOutreachCampaigns < ActiveRecord::Migration[8.1]
  def change
    create_table :outreach_campaigns do |t|
      t.references :organization, null: false, foreign_key: true
      t.references :owner, null: false, foreign_key: { to_table: :users }

      # 0 sms, 1 whatsapp
      t.integer :channel, null: false, default: 0
      # 0 prepared, 1 sending, 2 completed, 3 failed
      t.integer :status, null: false, default: 0
      t.text :body, null: false
      t.string :webhook_token, null: false
      t.string :last_error
      t.integer :total_count, null: false, default: 0
      t.integer :sent_count, null: false, default: 0
      t.integer :delivered_count, null: false, default: 0
      t.integer :failed_count, null: false, default: 0

      t.timestamps
    end

    add_index :outreach_campaigns, :webhook_token, unique: true
    add_index :outreach_campaigns, [ :organization_id, :created_at ]

    create_table :outreach_recipients do |t|
      t.references :outreach_campaign, null: false, foreign_key: true
      t.references :organization, null: false, foreign_key: true

      t.string :phone, null: false
      # 0 pending, 1 sent, 2 delivered, 3 failed
      t.integer :status, null: false, default: 0
      t.string :provider_message_id
      t.string :error_message
      t.datetime :sent_at
      t.datetime :delivered_at

      t.timestamps
    end

    add_index :outreach_recipients, [ :outreach_campaign_id, :phone ], unique: true
    add_index :outreach_recipients, [ :organization_id, :status ]
  end
end
