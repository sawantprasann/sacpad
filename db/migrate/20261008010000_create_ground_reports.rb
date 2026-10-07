class CreateGroundReports < ActiveRecord::Migration[8.1]
  def change
    # Village field report (Story 3.1, FR27). organization_id is NOT NULL + FK.
    # Testimonials are children; worship, yatra, contacts, and mock poll are later stories.
    create_table :ground_reports do |t|
      t.references :owner, null: false, foreign_key: { to_table: :users }
      t.references :organization, null: false, foreign_key: true
      t.references :village, null: false, foreign_key: true

      t.text :issue_text, null: false
      t.text :resolution_text
      t.date :reported_at, null: false

      t.datetime :discarded_at
      t.bigint   :discarded_by_id

      t.timestamps
    end

    add_index :ground_reports, :discarded_at
    add_index :ground_reports, [ :organization_id, :village_id ]
    add_index :ground_reports, [ :organization_id, :owner_id ]

    create_table :ground_report_testimonials do |t|
      t.references :ground_report, null: false, foreign_key: true
      t.references :organization, null: false, foreign_key: true
      t.references :created_by, null: false, foreign_key: { to_table: :users }

      t.string  :person_name, null: false
      t.integer :content_type, null: false
      t.text    :text_content

      t.datetime :discarded_at
      t.bigint   :discarded_by_id

      t.timestamps
    end

    add_index :ground_report_testimonials, :discarded_at
  end
end