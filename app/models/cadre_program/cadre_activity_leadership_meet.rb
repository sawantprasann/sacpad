module CadreProgram
  class CadreActivityLeadershipMeet < ApplicationRecord
    self.table_name = "cadre_activity_leadership_meets"
    include ActivityDetail

    validates :whom_to_meet, presence: true
  end
end
