module Console
  # Inbox for app complaints. Full admins see every organization; ops admins see
  # only the organizations assigned to them.
  class SupportTicketsController < BaseController
    around_action :without_tenant
    before_action :set_ticket, only: %i[show reply]

    def index
      scope = support_scope
      @counts = SupportTicket.summary_counts(scope)
      @pagy, @tickets = pagy(:offset, SupportTicket.apply_list_filters(scope, status: params[:status], query: params[:q]).preload(:user, :organization))
    end

    def show
    end

    def reply
      body = params.dig(:support_message, :body).to_s
      files = Array(params.dig(:support_message, :images)).reject(&:blank?)
      status = params.dig(:support_ticket, :status).to_s
      status = nil unless SupportTicket.statuses.key?(status)

      if body.strip.blank? && files.empty? && (status.blank? || status == @ticket.status)
        @message = @ticket.messages.build
        @message.errors.add(:body, "can't be blank")
        render :show, status: :unprocessable_entity
        return
      end

      notice = "Status updated."
      SupportTicket.transaction do
        if body.strip.present? || files.any?
          message = @ticket.messages.build(body: body, author: current_admin, organization: @ticket.organization)
          message.images.attach(files) if files.any?
          message.save!
          notice = "Reply sent."
        end
        @ticket.update!(status: status) if status.present? && status != @ticket.status
      end
      redirect_to console_support_ticket_path(@ticket), notice: notice
    rescue ActiveRecord::RecordInvalid => error
      @message = error.record.is_a?(SupportMessage) ? error.record : SupportMessage.new(body: body)
      render :show, status: :unprocessable_entity
    end

    private

    def set_ticket
      @ticket = support_scope.preload(:user, :organization).find(params[:id])
      @ticket.messages.preload(:author).with_attached_images.load
      @message ||= SupportMessage.new
    end

    def support_scope
      scope = SupportTicket.all
      return scope if current_admin.full?

      scope.where(organization_id: current_admin.organization_ids)
    end

    def without_tenant
      ActsAsTenant.without_tenant { yield }
    end
  end
end
