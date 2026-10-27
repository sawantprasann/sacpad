class ConstituencyElectionCandidate < ApplicationRecord
  belongs_to :constituency_election, inverse_of: :candidates
  belongs_to :party

  validates :candidate_name, presence: true
  validates :votes, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :vote_percent, presence: true, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 100 }
  validates :vote_change, numericality: true, allow_nil: true
  validates :position, presence: true, numericality: { only_integer: true, greater_than: 0 }

  before_validation :clear_change_for_new_contestant

  private

  def clear_change_for_new_contestant
    self.vote_change = nil if new_contestant?
  end
end
