class AssistantMessage < ApplicationRecord
  include OrganizationScoped

  belongs_to :conversation, class_name: "AssistantConversation", foreign_key: :assistant_conversation_id

  enum :speaker, { from_user: 0, from_assistant: 1 }

  validates :body, presence: true
end
