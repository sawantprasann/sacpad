module Assistant
  # Saves nothing itself. The question row already exists. The answer is pushed
  # to the open page when Ollama finishes, so the browser can send another question.
  class AnswerJob < ApplicationJob
    queue_as :default

    def perform(user_message_id, pending_id, locale, tries = 0)
      I18n.locale = locale
      message = AssistantMessage.unscoped.find_by(id: user_message_id)
      return if message.nil? || !message.from_user?
      return unless pending_id.match?(/\Apending-[0-9a-f-]{8,}\z/i)

      conversation = AssistantConversation.unscoped.find(message.assistant_conversation_id)
      ActsAsTenant.with_tenant(conversation.organization) do
        result = Lane.exclusive do
          answered_ids = conversation.messages.from_assistant.where.not(reply_to_id: nil).select(:reply_to_id)
          earlier = conversation.messages.from_user.where("id < ?", message.id).where.not(id: answered_ids).exists?
          if earlier
            :wait
          elsif conversation.messages.from_assistant.exists?(reply_to_id: message.id)
            :skip
          else
            Ask.new(
              user: conversation.user,
              conversation: conversation,
              question: message.body,
              save_question: false,
              user_message: message
            ).call
            :done
          end
        end

        if result == false || result == :wait
          self.class.set(wait: 2.seconds).perform_later(user_message_id, pending_id, locale, tries + 1) if tries < 200
          return
        end
        return unless result == :done

        answer = conversation.messages.from_assistant.find_by(reply_to_id: message.id)
        return if answer.nil?

        Turbo::StreamsChannel.broadcast_replace_to(
          conversation,
          target: pending_id,
          partial: "assistant/conversations/message",
          locals: { message: answer }
        )
      end
    end
  end
end
