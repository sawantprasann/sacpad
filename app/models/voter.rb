class Voter < ApplicationRecord
  # Global electoral-roll record — shared data across all organizations (§6.7 v2).
  # Only voter data (voter_id, name, mobile, booth) is global; sentiment tracking is org-scoped
  # via VoterSentiment table. The Voter Lists bulk-import experience (Epic 6) uploads once here,
  # and all orgs reference the same records.
  include FullyVersioned   # Tier-1 VoterVersion history for PII edits

  belongs_to :booth, optional: true
  belongs_to :state, optional: true
  belongs_to :loksabha, optional: true
  belongs_to :assembly, optional: true
  belongs_to :village, optional: true
  has_many :voter_sentiments, dependent: :destroy
  has_many :voter_turnouts, dependent: :destroy

  # sr_no is the voter's position on that booth's published roll.

  # PII encrypted at rest (NFR18). Name fields deterministic for searchability.
  # voter_id is deterministic for Ticket lookup; name fields deterministic for voter search/filter.
  encrypts :voter_id, deterministic: true
  encrypts :first_name, deterministic: true
  encrypts :last_name, deterministic: true
  encrypts :middle_name, deterministic: true
  encrypts :mobile

  validates :first_name, :last_name, presence: true

  def name
    [ first_name, middle_name, last_name ].compact_blank.join(" ")
  end

  # Each word must appear somewhere in the full name. "tanaji savant" matches
  # "Tanaji Jayvant Savant" because the middle name does not have to be typed.
  def matches_name?(query)
    words = query.to_s.squish.downcase.split
    return false if words.empty?

    full = name.downcase
    words.all? { |word| full.include?(word) }
  rescue ActiveRecord::Encryption::Errors::Decryption
    false
  end

  # Male, female, other, and blank genders for a voter set. Defaults to every voter.
  def self.gender_counts(relation = all)
    totals = { male: 0, female: 0, others: 0, unspecified: 0 }
    relation.group(:gender).count.each do |gender, count|
      totals[gender_bucket(gender)] += count
    end
    totals
  end

  # Fetched voters against the male, female, and other totals saved from booth roll PDFs.
  def self.coverage
    fetched = gender_counts
    pdf = Booth.elector_totals
    {
      fetched: fetched.merge(total: fetched.values.sum),
      pdf: pdf&.merge(total: pdf.values.sum)
    }
  end

  def self.gender_bucket(gender)
    case gender.to_s.strip
    when /\A(male|m)\z/i then :male
    when /\A(female|f)\z/i then :female
    when "" then :unspecified
    else :others
    end
  end
  private_class_method :gender_bucket
end
