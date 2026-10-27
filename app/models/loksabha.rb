class Loksabha < ApplicationRecord
  belongs_to :state
  belongs_to :district, optional: true
  has_many :assemblies, dependent: :restrict_with_error
  has_many :election_results, class_name: "ConstituencyElection", as: :constituency, inverse_of: :constituency, dependent: :restrict_with_error
  has_many :voters, dependent: :restrict_with_error
  validates :name, presence: true
end
