class BoothChecklistItem < ApplicationRecord
  include OrganizationScoped

  belongs_to :booth

  validates :label, presence: true
end
