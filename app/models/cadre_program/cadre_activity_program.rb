module CadreProgram
  # Shared by Program By Party and Personal Program (brief §6.2).
  class CadreActivityProgram < ApplicationRecord
    self.table_name = "cadre_activity_programs"
    include ActivityDetail

    validates :program_name, presence: true
  end
end
