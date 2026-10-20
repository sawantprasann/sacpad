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
      destroy_and_redirect({ action: :index })
    end

    private

    def destroy_and_redirect(redirect_path)
      if @record.destroy
        redirect_to redirect_path, notice: "#{managed_title} deleted."
      else
        redirect_to redirect_path, alert: deletion_failure_message(@record)
      end
    rescue ActiveRecord::InvalidForeignKey
      redirect_to redirect_path, alert: deletion_failure_message(@record)
    end

    def set_record
      @record = managed_model.find(params[:id])
    end

    def record_params
      params.require(:record).permit(*managed_fields)
    end

    # Where Cancel returns. Catalogs without a show page go back to the list.
    # The id from the edit URL must be dropped, or this resolves to the member path.
    # Subclasses with a detail page (district, taluka, loksabha, assembly, village) override this.
    def reference_cancel_path
      polymorphic_path([ :console, managed_model ])
    end
    helper_method :managed_fields, :managed_title, :reference_cancel_path
  end
end
