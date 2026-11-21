module Assistant
  class ConversationsController < ApplicationController
    before_action :authenticate_user!
    before_action :require_assistant_access

    def index
      if params[:fresh].present?
        conversation = AssistantConversation.create!(user: current_user, organization: current_user.organization)
        redirect_to assistant_conversation_path(conversation)
        return
      end

      load_history
      @conversation = @conversations.first ||
        AssistantConversation.create!(user: current_user, organization: current_user.organization)
      @messages = @conversation.messages.order(:id)
      render :show
    end

    def show
      load_history
      @conversation = user_conversations.find(params[:id])
      @messages = @conversation.messages.order(:id)
    end

    def create
      body = params[:body].to_s.strip
      if body.blank?
        redirect_to return_path, alert: t("assistant.blank")
        return
      end
      if body.length > 2000
        redirect_to return_path, alert: t("assistant.too_long")
        return
      end

      @conversation = if params[:conversation_id].present?
        user_conversations.find(params[:conversation_id])
      else
        AssistantConversation.create!(user: current_user, organization: current_user.organization)
      end

      respond_to do |format|
        format.turbo_stream do
          @user_message = @conversation.messages.create!(
            organization: current_user.organization,
            speaker: :from_user,
            body: body
          )
          Assistant::AnswerJob.perform_later(@user_message.id, pending_id, I18n.locale.to_s)
          load_history
        end
        format.html do
          Assistant::Ask.new(user: current_user, conversation: @conversation, question: body).call
          redirect_to assistant_conversation_path(@conversation)
        end
      end
    end

    private

    def load_history
      @conversations = user_conversations
        .where(id: AssistantMessage.from_user.select(:assistant_conversation_id))
        .includes(:messages)
        .limit(30)
    end

    def user_conversations
      AssistantConversation.where(user_id: current_user.id).order(id: :desc)
    end

    def pending_id
      value = params[:pending_id].to_s
      value.match?(/\Apending-[0-9a-f-]{8,}\z/i) ? value : "pending-#{SecureRandom.uuid}"
    end

    def return_path
      conversation = user_conversations.find_by(id: params[:conversation_id]) if params[:conversation_id].present?
      conversation ? assistant_conversation_path(conversation) : assistant_conversations_path(fresh: 1)
    end

    def require_assistant_access
      return if Assistant::Catalog.available?(current_user)

      raise Pundit::NotAuthorizedError
    end
  end
end
