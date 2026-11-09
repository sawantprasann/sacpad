module SocialMedia
  # One row per connected page per day. Weekly and monthly figures are summed from these.
  class PageMetricSnapshot < ApplicationRecord
    self.table_name = "social_page_metric_snapshots"

    include OrganizationScoped

    belongs_to :social_page, class_name: "SocialMedia::SocialPage"

    validates :captured_on, presence: true
    validates :captured_on, uniqueness: { scope: :social_page_id }
  end
end
