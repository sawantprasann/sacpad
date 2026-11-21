class AssistantConversation < ApplicationRecord
  include OrganizationScoped

  PLACE_TYPES = %w[Village Taluka Booth].freeze

  belongs_to :user
  belongs_to :place, polymorphic: true, optional: true
  has_many :messages, class_name: "AssistantMessage", dependent: :delete_all

  validates :place_type, inclusion: { in: PLACE_TYPES }, allow_nil: true

  def title
    messages.select(&:from_user?).min_by(&:id)&.body.to_s.squish.truncate(42).presence || I18n.t("assistant.new_chat")
  end
end
