module CadreProgram
  class CadreActivityPersonalActivity < ApplicationRecord
    self.table_name = "cadre_activity_personal_activities"
    include ActivityDetail

    validates :activity_name, presence: true
  end
end
