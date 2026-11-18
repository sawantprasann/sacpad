module Assistant
  class ConversationsController < ApplicationController
    before_action :authenticate_user!
    before_action :require_assistant_access

    def index
      load_history
      if params[:fresh]
        @conversation = nil
        @messages = AssistantMessage.none
      else
        @conversation = @conversations.first
        @messages = @conversation ? @conversation.messages.order(:id) : AssistantMessage.none
      end
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
      Assistant::Ask.new(user: current_user, conversation: @conversation, question: body).call
      @assistant_message = @conversation.messages.from_assistant.order(:id).last
      load_history
      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to assistant_conversation_path(@conversation) }
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
