class Village < ApplicationRecord
  belongs_to :assembly
  has_many :booths, dependent: :restrict_with_error
  has_many :ground_reports, class_name: "GroundReports::GroundReport", dependent: :restrict_with_error
  has_many :worship_places, class_name: "GroundReports::WorshipPlace", dependent: :restrict_with_error
  has_one :village_yatra, class_name: "GroundReports::VillageYatra", dependent: :restrict_with_error
  has_many :political_positions, class_name: "GroundReports::VillagePoliticalPosition", dependent: :restrict_with_error
  has_many :local_karyakartas, class_name: "GroundReports::VillageLocalKaryakarta", dependent: :restrict_with_error
  has_many :local_admin_contacts, class_name: "GroundReports::VillageLocalAdminContact", dependent: :restrict_with_error
  has_many :mock_poll_responses, class_name: "GroundReports::MockPollResponse", dependent: :restrict_with_error
  validates :name, presence: true
end
