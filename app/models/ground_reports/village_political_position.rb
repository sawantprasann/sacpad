module GroundReports
  # History of who holds a local post (Story 3.2, FR28). A blank ended_at means current.
  # Opening a new current row closes the previous one.
  class VillagePoliticalPosition < ApplicationRecord
    self.table_name = "village_political_positions"

    include OrganizationScoped
    include SoftDeletable
    include VillageInConstituency

    belongs_to :village
    belongs_to :party

    validates :representative_name, :position_title, :started_at, presence: true

    before_create :close_previous_current, if: -> { ended_at.nil? }

    scope :current, -> { where(ended_at: nil) }

    private

    def close_previous_current
      self.class.where(village_id: village_id, organization_id: organization_id, ended_at: nil)
                .update_all(ended_at: started_at, updated_at: Time.current)
    end
  end
end
