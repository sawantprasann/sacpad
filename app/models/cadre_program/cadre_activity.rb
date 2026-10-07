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
      "personal_activities" => :personal_activity,
      "one_to_one" => :one_to_one
    }.freeze

    has_one :program, class_name: "CadreProgram::CadreActivityProgram", dependent: :destroy, inverse_of: :cadre_activity
    has_one :leadership_meet, class_name: "CadreProgram::CadreActivityLeadershipMeet", dependent: :destroy, inverse_of: :cadre_activity
    has_one :party_program_hosted, class_name: "CadreProgram::CadreActivityPartyProgramHosted", dependent: :destroy, inverse_of: :cadre_activity
    has_one :personal_activity, class_name: "CadreProgram::CadreActivityPersonalActivity", dependent: :destroy, inverse_of: :cadre_activity
    has_one :one_to_one, class_name: "CadreProgram::CadreActivityOneToOne", dependent: :destroy, inverse_of: :cadre_activity

    accepts_nested_attributes_for :program, :leadership_meet, :party_program_hosted, :personal_activity, :one_to_one,
                                  reject_if: :all_blank

    # Fixed categories (not an Admin catalog). Integer map is append-only — never reorder.
    enum :category, {
      program_by_party: 0,
      leadership_meets: 1,
      party_programs_hosted: 2,
      personal_program: 3,
      personal_activities: 4,
      one_to_one: 5
    }

    CATEGORY_LABELS = {
      "program_by_party" => "Program By Party",
      "leadership_meets" => "Leadership Meets",
      "party_programs_hosted" => "Party Programs Hosted",
      "personal_program" => "Personal Program",
      "personal_activities" => "Personal Activities",
      "one_to_one" => "One To One"
    }.freeze

    validates :category, presence: true

    before_validation :keep_only_matching_detail
    validate :matching_detail_required

    def category_label
      CATEGORY_LABELS[category]
    end

    # Feed and export rollups. One GROUP BY on this table — not a union of the detail tables.
    # reorder clears the list's ORDER BY, which PostgreSQL rejects beside GROUP BY.
    def self.counts_by_category
      reorder(nil).group(:category).count.each_with_object({}) do |(key, count), labeled|
        slug = key.is_a?(Integer) ? categories.key(key) : key.to_s
        labeled[CATEGORY_LABELS.fetch(slug, slug)] = count
      end
    end

    def matching_detail
      name = DETAIL_ASSOCIATIONS[category]
      name && public_send(name)
    end

    # One-line label for the list: the name of the program, the person met, or the karyakarta.
    def detail_headline
      detail = matching_detail
      case detail
      when CadreActivityProgram, CadreActivityPartyProgramHosted then detail.program_name
      when CadreActivityLeadershipMeet then detail.whom_to_meet
      when CadreActivityPersonalActivity then detail.activity_name
      when CadreActivityOneToOne then detail.karyakarta_user&.name || detail.karyakarta_name_text
      end
    end

    private

    # A tampered form can submit every fieldset. Only the shape for this category is kept.
    def keep_only_matching_detail
      keep = DETAIL_ASSOCIATIONS[category]
      %i[program leadership_meet party_program_hosted personal_activity one_to_one].each do |name|
        next if name == keep

        public_send("#{name}=", nil) if public_send(name)&.new_record?
      end
    end

    def matching_detail_required
      return if category.blank?

      errors.add(:base, "Fill in the #{category_label} details") if matching_detail.nil?
    end
  end
end
