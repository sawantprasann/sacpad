class RolePermission < ApplicationRecord
  belongs_to :role

  enum :module_name, {
    kitchen_cabinet: 0, cadre_program: 1, ground_reports: 2, pr: 3,
    mainline_fan_page_media: 4, social_media: 5, voter_lists: 6, rag_mapping: 7
  }
  # prefix avoids clashing with ActiveRecord's `.none` relation method.
  enum :access_level, { none: 0, read: 1, write: 2 }, prefix: :access

  validates :module_name, uniqueness: { scope: :role_id }
end
