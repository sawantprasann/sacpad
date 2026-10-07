module CadreProgram
  # One To One references a karyakarta as a User when they have a login, otherwise by name (FR25).
  class CadreActivityOneToOne < ApplicationRecord
    self.table_name = "cadre_activity_one_to_ones"
    include ActivityDetail

    belongs_to :karyakarta_user, class_name: "User", optional: true

    validates :karyakarta_name_text, presence: true, if: -> { karyakarta_user_id.blank? }
    validate :karyakarta_belongs_to_organization

    private

    def karyakarta_belongs_to_organization
      return if karyakarta_user_id.blank?

      expected = organization_id || cadre_activity&.organization_id
      return if karyakarta_user&.organization_id.present? && karyakarta_user.organization_id == expected

      errors.add(:karyakarta_user, "must be someone in this organization")
    end
  end
end
