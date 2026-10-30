module CadreProgram
  # Shared base row for every cadre category (Story 2.1, brief §6.2). Per-category detail
  # tables arrive in Story 2.2; this row is what scoping, the feed, and export key off.
  # Table name is pinned — a namespaced model would otherwise seek cadre_program_cadre_activities.
  class CadreActivity < ApplicationRecord
    self.table_name = "cadre_activities"

    include OrganizationScoped
    include SoftDeletable

    belongs_to :owner, class_name: "User"
    has_many_attached :photos

    # program_by_party and personal_program share :program. The other categories have their own row.
    DETAIL_ASSOCIATIONS = {
      "program_by_party" => :program,
      "personal_program" => :program,
      "leadership_meets" => :leadership_meet,
      "party_programs_hosted" => :party_program_hosted,
      "one_to_one" => :one_to_one
    }.freeze

    has_one :program, class_name: "CadreProgram::CadreActivityProgram", dependent: :destroy, inverse_of: :cadre_activity
    has_one :leadership_meet, class_name: "CadreProgram::CadreActivityLeadershipMeet", dependent: :destroy, inverse_of: :cadre_activity
    has_one :party_program_hosted, class_name: "CadreProgram::CadreActivityPartyProgramHosted", dependent: :destroy, inverse_of: :cadre_activity
    has_one :one_to_one, class_name: "CadreProgram::CadreActivityOneToOne", dependent: :destroy, inverse_of: :cadre_activity

    accepts_nested_attributes_for :program, :leadership_meet, :party_program_hosted, :one_to_one,
                                  reject_if: :all_blank

    # Fixed categories (not an Admin catalog). Integer map is append-only — never reorder.
    # 4 was personal_activities and is retired; do not reuse it.
    enum :category, {
      program_by_party: 0,
      leadership_meets: 1,
      party_programs_hosted: 2,
      personal_program: 3,
      one_to_one: 5
    }

    CATEGORY_LABELS = {
      "program_by_party" => "Program By Party",
      "leadership_meets" => "Leadership Meets",
      "party_programs_hosted" => "Party Programs Hosted",
      "personal_program" => "Personal Program",
      "one_to_one" => "One To One"
    }.freeze

    # Columns for a category submenu. The unfiltered list keeps a short shared set because
    # the shapes do not line up.
    PROGRAM_LIST_COLUMNS = [
      [ "program_name", ->(activity) { activity.program&.program_name } ],
      [ "occasion", ->(activity) { activity.program&.occasion } ],
      [ "location", ->(activity) { activity.program&.location } ],
      [ "host", ->(activity) { activity.program&.host } ],
      [ "occurred_on", ->(activity) { activity.program&.occurred_on } ]
    ].freeze
    LIST_COLUMNS = {
      "program_by_party" => PROGRAM_LIST_COLUMNS,
      "personal_program" => PROGRAM_LIST_COLUMNS,
      "leadership_meets" => [
        [ "whom_to_meet", ->(activity) { activity.leadership_meet&.whom_to_meet } ],
        [ "point_of_discussion", ->(activity) { activity.leadership_meet&.point_of_discussion } ],
        [ "work_submitted", ->(activity) { activity.leadership_meet&.work_submitted } ],
        [ "submitted_on", ->(activity) { activity.leadership_meet&.submitted_on } ],
        [ "follow_up_on", ->(activity) { activity.leadership_meet&.followup_on } ]
      ].freeze,
      "party_programs_hosted" => [
        [ "program_name", ->(activity) { activity.party_program_hosted&.program_name } ],
        [ "location", ->(activity) { activity.party_program_hosted&.location } ],
        [ "total_attendees", ->(activity) { activity.party_program_hosted&.total_attendees } ],
        [ "print_media", ->(activity) { activity.party_program_hosted&.print_media } ],
        [ "electronic_media", ->(activity) { activity.party_program_hosted&.electronic_media } ],
        [ "hosted_on", ->(activity) { activity.party_program_hosted&.hosted_on } ]
      ].freeze,
      "one_to_one" => [
        [ "karyakarta", ->(activity) { activity.one_to_one&.karyakarta_user&.name || activity.one_to_one&.karyakarta_name_text } ],
        [ "assignment", ->(activity) { activity.one_to_one&.assignment } ],
        [ "resolved", ->(activity) { detail = activity.one_to_one; detail && (detail.resolved? ? I18n.t("common.yes") : I18n.t("common.no")) } ],
        [ "from", ->(activity) { activity.one_to_one&.from_date } ],
        [ "to", ->(activity) { activity.one_to_one&.to_date } ]
      ].freeze
    }.freeze
    DEFAULT_LIST_COLUMNS = [
      [ "activity", ->(activity) { activity.detail_headline } ],
      [ "category", ->(activity) { activity.category_label } ],
      [ "occurred_on", ->(activity) { activity.occurred_on } ]
    ].freeze

    def self.list_columns(category_key)
      LIST_COLUMNS.fetch(category_key.to_s, DEFAULT_LIST_COLUMNS).map do |key, reader|
        [ I18n.t("cadre_program.columns.#{key}"), reader ]
      end
    end

    validates :category, presence: true

    before_validation :keep_only_matching_detail
    validate :matching_detail_required

    def self.localized_category(key)
      label = CATEGORY_LABELS[key.to_s]
      return if label.blank?

      I18n.t("cadre_program.categories.#{key}", default: label)
    end

    def self.localized_category_labels
      CATEGORY_LABELS.keys.index_with { |key| localized_category(key) }
    end

    def category_label
      self.class.localized_category(category)
    end

    # Feed and export rollups. One GROUP BY on this table — not a union of the detail tables.
    # reorder clears the list's ORDER BY, which PostgreSQL rejects beside GROUP BY.
    def self.counts_by_category
      reorder(nil).group(:category).count.each_with_object({}) do |(key, count), labeled|
        slug = key.is_a?(Integer) ? categories.key(key) : key.to_s
        labeled[localized_category(slug) || slug] = count
      end
    end

    def matching_detail
      name = DETAIL_ASSOCIATIONS[category]
      name && public_send(name)
    end

    # The day the work happened. Programs store occurred_on; the other categories use their own date.
    def occurred_on
      detail = matching_detail
      case detail
      when CadreActivityProgram then detail.occurred_on
      when CadreActivityPartyProgramHosted then detail.hosted_on
      when CadreActivityLeadershipMeet then detail.submitted_on
      when CadreActivityOneToOne then detail.from_date
      end
    end

    # One-line label for the list: the name of the program, the person met, or the karyakarta.
    def detail_headline
      detail = matching_detail
      case detail
      when CadreActivityProgram, CadreActivityPartyProgramHosted then detail.program_name
      when CadreActivityLeadershipMeet then detail.whom_to_meet
      when CadreActivityOneToOne then detail.karyakarta_user&.name || detail.karyakarta_name_text
      end
    end

    private

    # A tampered form can submit every fieldset. Only the shape for this category is kept.
    def keep_only_matching_detail
      keep = DETAIL_ASSOCIATIONS[category]
      %i[program leadership_meet party_program_hosted one_to_one].each do |name|
        next if name == keep

        detail = public_send(name)
        next unless detail

        if detail.new_record?
          public_send("#{name}=", nil)
        else
          detail.mark_for_destruction
        end
      end
    end

    def matching_detail_required
      return if category.blank?

      errors.add(:base, "Fill in the #{category_label} details") if matching_detail.nil?
    end
  end
end
