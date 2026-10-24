class SupportTicketsController < ApplicationController
  # Any signed-in person can raise a complaint about the app and follow their own thread.
  # Other people's tickets stay hidden. Platform replies happen in the console.
  before_action :authenticate_user!
  before_action :set_ticket, only: %i[show reply]

  def index
    scope = SupportTicket.where(user_id: current_user.id)
    @counts = SupportTicket.summary_counts(scope)
    @pagy, @tickets = pagy(:offset, SupportTicket.apply_list_filters(scope, status: params[:status], query: params[:q]))
  end

  def new
    @ticket = SupportTicket.new(category: :general)
  end

  def create
    @ticket = current_user.support_tickets.new(ticket_params)
    @ticket.organization = current_user.organization
    if @ticket.save
      redirect_to support_ticket_path(@ticket), notice: "Your complaint has been sent. We'll reply on this page."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def show
  end

  def reply
    @message = @ticket.messages.build(body: params.dig(:support_message, :body), author: current_user, organization: current_user.organization)
    files = uploaded_images(:support_message)
    @message.images.attach(files) if files.any?
    if @message.save
      reopened = @ticket.solved? || @ticket.on_hold?
      @ticket.update!(status: :pending) if reopened
      notice = reopened ? "Reply sent. This ticket is open again." : "Reply sent."
      redirect_to support_ticket_path(@ticket), notice: notice
    else
      render :show, status: :unprocessable_entity
    end
  end

  private

  def set_ticket
    @ticket = SupportTicket.where(user_id: current_user.id).find(params[:id])
    @ticket.messages.preload(:author).with_attached_images.load
    @message ||= SupportMessage.new
  end

  def ticket_params
    permitted = params.require(:support_ticket).permit(:subject, :category, :opening_body, images: [])
    permitted.delete(:category) unless SupportTicket.categories.key?(permitted[:category].to_s)
    permitted[:images] = Array(permitted[:images]).reject(&:blank?)
    permitted
  end

  def uploaded_images(scope)
    Array(params.dig(scope, :images)).reject(&:blank?)
  end
end
