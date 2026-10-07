class CreateCadreActivityDetails < ActiveRecord::Migration[8.1]
  def change
    # Per-category detail rows (Story 2.2, brief §6.2). One shape is shared by two categories
    # (cadre_activity_programs). Each row is tenant-scoped and uniquely owned by its base activity.
    create_table :cadre_activity_programs do |t|
      t.references :cadre_activity, null: false, foreign_key: true, index: { unique: true }
      t.references :organization, null: false, foreign_key: true
      t.string :program_name, null: false
      t.string :occasion
      t.string :location
      t.date   :occurred_on
      t.string :host
      t.text   :notes
      t.timestamps
    end

    create_table :cadre_activity_leadership_meets do |t|
      t.references :cadre_activity, null: false, foreign_key: true, index: { unique: true }
      t.references :organization, null: false, foreign_key: true
      t.string :whom_to_meet, null: false
      t.text   :point_of_discussion
      t.text   :work_submitted
      t.date   :submitted_on
      t.date   :followup_on
      t.text   :resolution_notes
      t.timestamps
    end

    create_table :cadre_activity_party_program_hosteds do |t|
      t.references :cadre_activity, null: false, foreign_key: true, index: { unique: true }
      t.references :organization, null: false, foreign_key: true
      t.string  :program_name, null: false
      t.date    :hosted_on
      t.string  :location
      t.integer :total_attendees
      t.string  :print_media
      t.string  :electronic_media
      t.timestamps
    end

    create_table :cadre_activity_personal_activities do |t|
      t.references :cadre_activity, null: false, foreign_key: true, index: { unique: true }
      t.references :organization, null: false, foreign_key: true
      t.string :activity_name, null: false
      t.string :occasion
      t.string :total_submission
      t.date   :from_date
      t.date   :to_date
      t.text   :notes
      t.timestamps
    end

    create_table :cadre_activity_one_to_ones do |t|
      t.references :cadre_activity, null: false, foreign_key: true, index: { unique: true }
      t.references :organization, null: false, foreign_key: true
      t.references :karyakarta_user, foreign_key: { to_table: :users }, index: true
      t.string  :karyakarta_name_text
      t.string  :assignment
      t.boolean :resolved, null: false, default: false
      t.date    :from_date
      t.date    :to_date
      t.text    :notes
      t.timestamps
    end
  end
end
