module CadreProgram
  class CadreActivityPartyProgramHosted < ApplicationRecord
    self.table_name = "cadre_activity_party_program_hosteds"
    include ActivityDetail

    validates :program_name, presence: true
  end
end
