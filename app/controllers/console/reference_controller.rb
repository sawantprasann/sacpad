module Console
  # Reusable Admin catalog-editor pattern (Story 0.4 AC). Subclasses declare a model and the
  # editable fields; this base provides standard CRUD over shared views. Reused by geography
  # (states→booths), parties, and later ticket/PR categories, media platforms, ad types.
  #
  # Fields ending in `_id` render as a collection select (inferred class), others as text inputs.
  class ReferenceController < BaseController
    class_attribute :managed_model, :managed_fields, :managed_title

    before_action :set_record, only: %i[edit update destroy]

    def index
      @records = managed_model.order(:id)
      render "console/reference/index"
    end

    def new
      @record = managed_model.new
      render "console/reference/new"
    end

    def create
      @record = managed_model.new(record_params)
      if @record.save
        redirect_to({ action: :index }, notice: "#{managed_title} created.")
      else
        render "console/reference/new", status: :unprocessable_entity
      end
    end

    def edit
      render "console/reference/edit"
    end

    def update
      if @record.update(record_params)
        redirect_to({ action: :index }, notice: "#{managed_title} updated.")
      else
        render "console/reference/edit", status: :unprocessable_entity
      end
    end

    def destroy
      @record.destroy
      redirect_to({ action: :index }, notice: "#{managed_title} deleted.")
    rescue ActiveRecord::InvalidForeignKey, ActiveRecord::RecordNotDestroyed
      redirect_to({ action: :index }, alert: "Can't delete — it still has dependent records.")
    end

    private

    def set_record
      @record = managed_model.find(params[:id])
    end

    def record_params
      params.require(:record).permit(*managed_fields)
    end
    helper_method :managed_fields, :managed_title
  end
end
