class Voter < ApplicationRecord
  # Global electoral-roll record — shared data across all organizations (§6.7 v2).
  # Only voter data (voter_id, name, mobile, booth) is global; sentiment tracking is org-scoped
  # via VoterSentiment table. The Voter Lists bulk-import experience (Epic 6) uploads once here,
  # and all orgs reference the same records.
  include FullyVersioned   # Tier-1 VoterVersion history for PII edits
  self.paper_trail_options = paper_trail_options.merge(
    skip: Array(paper_trail_options[:skip]) | [ "name_search_tokens" ]
  )

  belongs_to :booth, optional: true
  belongs_to :state, optional: true
  belongs_to :loksabha, optional: true
  belongs_to :assembly, optional: true
  belongs_to :village, optional: true
  has_many :voter_sentiments, dependent: :destroy
  has_many :voter_turnouts, dependent: :destroy

  # sr_no is the voter's position on that booth's published roll.
  # Numeric booth numbers sort as integers (2 before 10). Other numbers follow, then voters with no booth.
  # Missing serials stay at the end of their booth.
  scope :by_booth_and_serial, -> {
    left_joins(:booth).order(
      Arel.sql("CASE WHEN booths.number ~ '^[0-9]+$' THEN booths.number::bigint END ASC NULLS LAST"),
      Arel.sql("booths.number ASC NULLS LAST"),
      Arel.sql("voters.sr_no ASC NULLS LAST"),
      Arel.sql("voters.id ASC")
    )
  }

  # Case-insensitive substring match on the English and native names.
  scope :matching_name, ->(query) { NameSearch.apply(all, query) }

  # PII encrypted at rest (NFR18). voter_id is deterministic for Ticket lookup.
  # Name search uses name_search_tokens (HMAC substrings), not the ciphertext.
  encrypts :voter_id, deterministic: true
  encrypts :first_name, deterministic: true
  encrypts :last_name, deterministic: true
  encrypts :middle_name, deterministic: true
  encrypts :native_first_name, deterministic: true
  encrypts :native_last_name, deterministic: true
  encrypts :native_middle_name, deterministic: true
  encrypts :mobile

  validates :first_name, :last_name, presence: true

  before_validation :fill_native_person_names
  before_save :assign_name_search_tokens

  def name
    [ first_name, middle_name, last_name ].compact_blank.join(" ")
  end

  # English parts stay on first/middle/last. The Lok Sabha language is stored
  # on the native_* parts and shown when that language is selected.
  def display_name
    native = native_full_name
    return native if I18n.locale != I18n.default_locale && native.present?

    name
  end

  # Each word must appear somewhere in the full name. "tanaji savant" matches
  # "Tanaji Jayvant Savant" because the middle name does not have to be typed.
  # A Marathi spelling matches the native parts saved beside the English name.
  def matches_name?(query)
    words = query.to_s.squish.downcase.split
    return false if words.empty?

    words.all? { |word| searchable_name.include?(word) }
  rescue ActiveRecord::Encryption::Errors::Decryption
    false
  end

  def searchable_name
    self.class.searchable_name_from(
      first_name: first_name,
      middle_name: middle_name,
      last_name: last_name,
      native_first_name: native_first_name,
      native_middle_name: native_middle_name,
      native_last_name: native_last_name
    )
  end

  def self.searchable_name_from(...)
    NameSearch.searchable_from(...)
  end

  def self.name_search_tokens_for(...)
    NameSearch.tokens_for(searchable_name_from(...))
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

  def native_full_name
    [ native_first_name, native_middle_name, native_last_name ].compact_blank.join(" ")
  end

  def resolved_native_locale
    loksabha&.native_locale.presence ||
      assembly&.loksabha&.native_locale.presence ||
      village&.assembly&.loksabha&.native_locale
  end

  def assign_name_search_tokens
    tokens = self.class.name_search_tokens_for(
      first_name: first_name,
      middle_name: middle_name,
      last_name: last_name,
      native_first_name: native_first_name,
      native_middle_name: native_middle_name,
      native_last_name: native_last_name
    )
    self.name_search_tokens = tokens if name_search_tokens != tokens
  end

  def fill_native_person_names
    locale = resolved_native_locale.to_s
    return if locale.blank?

    %i[first_name middle_name last_name].each do |attr|
      native_attr = :"native_#{attr}"
      source = public_send(attr)
      native = public_send(native_attr)
      next if source.blank?
      next if native.present? && !public_send(:"#{attr}_changed?")
      next if will_save_change_to_attribute?(native_attr) && native.present?

      public_send(:"#{native_attr}=", NativeScript.transliterate(source, locale))
    end
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
