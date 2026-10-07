module GroundReports
  # A worship place in a village (Story 3.2, FR28). Type is free text, not a temple-only enum.
  class WorshipPlace < ApplicationRecord
    self.table_name = "worship_places"

    include OrganizationScoped
    include SoftDeletable
    include VillageInConstituency

    belongs_to :village

    validates :name, :place_type, presence: true
  end
end
