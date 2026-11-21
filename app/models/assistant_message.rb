class AssistantMessage < ApplicationRecord
  include OrganizationScoped

  belongs_to :conversation, class_name: "AssistantConversation", foreign_key: :assistant_conversation_id
  belongs_to :reply_to, class_name: "AssistantMessage", optional: true

  enum :speaker, { from_user: 0, from_assistant: 1 }

  validates :body, presence: true
end
