module Console
  # Booth administration — geography reference data with village/taluka context
  class BoothsController < BaseController
    before_action :set_booth, only: [:show, :edit, :update, :destroy]
    helper_method :booth_filters

    def index
      relation = Booth.includes(:village).order(:number)
      relation = relation.where(number: params[:booth_number].strip) if params[:booth_number].present?
      if params[:village].present?
        relation = relation.joins(:village).where("villages.name ILIKE ?", "%#{like(params[:village])}%")
      end
      @pagy, @booths = pagy(:offset, relation)
    end

    def show
    end

    def new
      @booth = Booth.new
    end

    def create
      @booth = Booth.new(booth_params)
      if @booth.save
        redirect_to console_booths_path, notice: "Booth created."
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit
    end

    def update
      if @booth.update(booth_params)
        redirect_to console_booths_path, notice: "Booth updated."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      @booth.destroy
      redirect_to console_booths_path, notice: "Booth deleted."
    rescue ActiveRecord::InvalidForeignKey, ActiveRecord::RecordNotDestroyed
      redirect_to console_booths_path, alert: "Can't delete — it still has dependent records."
    end

    private

    def set_booth
      @booth = Booth.find(params[:id])
    end

    def booth_params
      params.require(:booth).permit(:village_id, :number)
    end

    def booth_filters
      params.permit(:booth_number, :village).to_h
    end

    def like(value)
      ActiveRecord::Base.sanitize_sql_like(value.strip)
    end
  end
end
