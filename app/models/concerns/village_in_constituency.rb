# A village fact may only point at a village inside its organization's constituency.
module VillageInConstituency
  extend ActiveSupport::Concern

  included do
    validate :village_in_constituency
  end

  private

  def village_in_constituency
    return if village_id.blank? || organization.blank?
    return if organization.villages.exists?(id: village_id)

    errors.add(:village, "is outside this constituency")
  end
end
