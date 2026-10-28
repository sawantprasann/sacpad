class ConstituencyElection < ApplicationRecord
  # One past election for an Assembly or a Lok Sabha.
  # The organization's own `elections` row is the campaign it is working now.
  # This record is the published result for the seat, shared by every organization on that seat.
  CONSTITUENCY_TYPES = %w[Loksabha Assembly].freeze

  belongs_to :constituency, polymorphic: true, inverse_of: :election_results
  belongs_to :gained_from_party, class_name: "Party", optional: true
  has_many :candidates, -> { order(:position, :id) },
           class_name: "ConstituencyElectionCandidate",
           inverse_of: :constituency_election,
           dependent: :destroy

  accepts_nested_attributes_for :candidates, allow_destroy: true, reject_if: :blank_candidate?

  enum :outcome, { hold: 0, gain: 1 }, validate: true

  validates :year, presence: true,
                   numericality: { only_integer: true, greater_than: 1900, less_than: 2200 },
                   uniqueness: { scope: [ :constituency_type, :constituency_id ], message: "is already stored for this constituency" }
  validates :gained_from_party, presence: true, if: :gain?
  validates :swing, :margin_change, :turnout_change, :electors_change, numericality: true, allow_nil: true
  validates :margin_votes, :turnout_votes, :valid_votes, :registered_electors,
            numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true
  validates :margin_percent, :turnout_percent,
            numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 100 }, allow_nil: true
  validate :constituency_is_a_seat
  validate :gained_from_only_on_gain
  validate :one_winning_candidate

  before_validation :assign_candidate_positions

  def self.for_constituency(constituency)
    return none if constituency.blank?

    where(constituency: constituency).order(year: :desc)
  end

  def self.for_organization(organization)
    for_constituency(organization&.constituency).includes(:gained_from_party, candidates: :party)
  end

  def heading
    return title if title.present?

    "#{year} #{constituency_kind} election · #{constituency&.name}"
  end

  def constituency_kind
    constituency_type == "Loksabha" ? "Lok Sabha" : "Assembly"
  end

  def winning_candidate
    candidates.detect(&:winner?)
  end

  def result_label
    party = winning_candidate&.party
    name = party&.abbreviation.presence || party&.name
    return if name.blank?

    if gain? && gained_from_party
      from = gained_from_party.abbreviation.presence || gained_from_party.name
      "#{name} gain from #{from}"
    else
      "#{name} #{outcome}"
    end
  end

  private

  def blank_candidate?(attrs)
    attrs["id"].blank? && attrs["candidate_name"].blank? && attrs["votes"].blank? && attrs["party_id"].blank?
  end

  def assign_candidate_positions
    next_position = 1
    candidates.reject(&:marked_for_destruction?).each do |candidate|
      if candidate.position.to_i.positive?
        next_position = [ next_position, candidate.position.to_i + 1 ].max
      else
        candidate.position = next_position
        next_position += 1
      end
    end
  end

  def constituency_is_a_seat
    return if CONSTITUENCY_TYPES.include?(constituency_type)

    errors.add(:constituency, "must be an assembly or a Lok Sabha")
  end

  def gained_from_only_on_gain
    return unless hold? && gained_from_party_id.present?

    errors.add(:gained_from_party, "must be empty when the result is a hold")
  end

  def one_winning_candidate
    kept = candidates.reject(&:marked_for_destruction?)
    if kept.empty?
      errors.add(:base, "Add at least one candidate")
      return
    end

    winners = kept.count(&:winner?)
    errors.add(:base, "Mark one winning candidate") unless winners == 1
  end
end
