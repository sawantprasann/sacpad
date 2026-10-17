class Election < ApplicationRecord
  # One organization's election for the constituency it is working right now.
  # The voter roll stays global. Turnout is stored against this election, so a later
  # move from an assembly to a Lok Sabha starts a new election and leaves the old marks.
  include OrganizationScoped

  belongs_to :constituency, polymorphic: true, optional: true
  has_many :voter_turnouts, dependent: :destroy

  validates :name, presence: true

  def self.ensure_current!(organization)
    ActsAsTenant.with_tenant(organization) do
      current = find_by(current: true)
      return current if current&.covers?(organization)

      transaction do
        where(current: true).update_all(current: false, updated_at: Time.current)
        create!(
          name: label_for(organization),
          constituency: organization.constituency,
          current: true
        )
      end
    end
  end

  def self.label_for(organization)
    place = organization.constituency&.name
    kind = organization.constituency_type
    ([ place, kind ].compact + [ Time.current.year ]).join(" · ")
  end

  def covers?(organization)
    constituency_type.to_s == organization.constituency_type.to_s &&
      constituency_id == organization.constituency_id
  end
end
