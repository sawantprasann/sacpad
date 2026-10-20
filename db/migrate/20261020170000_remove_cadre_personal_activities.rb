class RemoveCadrePersonalActivities < ActiveRecord::Migration[8.1]
  # Personal Activities (category integer 4) is retired. Personal Program stays.
  # The integer is left unused so the remaining category values do not shift.
  def up
    execute <<~SQL.squish
      DELETE FROM active_storage_attachments
      WHERE record_type = 'CadreProgram::CadreActivity'
        AND record_id IN (SELECT id FROM cadre_activities WHERE category = 4)
    SQL
    execute <<~SQL.squish
      DELETE FROM activity_logs
      WHERE record_type = 'CadreProgram::CadreActivity'
        AND record_id IN (SELECT id FROM cadre_activities WHERE category = 4)
    SQL
    drop_table :cadre_activity_personal_activities
    execute "DELETE FROM cadre_activities WHERE category = 4"
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
