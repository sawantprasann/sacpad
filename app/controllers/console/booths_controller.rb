module Console
  # Booth administration — geography reference data with village/taluka context
  class BoothsController < BaseController
    before_action :set_booth, only: [ :show, :edit, :update, :destroy ]
    helper_method :booth_filters, :voter_filters

    def index
      relation = Booth.includes(village: { taluka: { district: :state } }).by_number
      relation = relation.where(number: params[:booth_number].strip) if params[:booth_number].present?
      relation = relation.where(village_id: params[:village_id]) if params[:village_id].present?
      if params[:taluka_id].present? || params[:district_id].present?
        relation = relation.joins(village: :taluka)
        relation = relation.where(villages: { taluka_id: params[:taluka_id] }) if params[:taluka_id].present?
        relation = relation.where(talukas: { district_id: params[:district_id] }) if params[:district_id].present?
      end
      @districts = District.order(:name)
      @talukas = Taluka.order(:name)
      @villages = Village.includes(:taluka).order(:name)
      @pagy, @booths = pagy(:offset, relation)
    end

    def show
      @voter_total = @booth.voters.count
      @gender_counts = @booth.voter_gender_counts
      relation = @booth.voters.order(:id)
      relation = relation.where(voter_id: params[:voter_id].strip) if params[:voter_id].present?
      if params[:age].present?
        age = Integer(params[:age], exception: false)
        relation = age ? relation.where(age: age) : relation.none
      end
      relation = relation.where("voters.gender ILIKE ?", like_pattern(params[:gender])) if params[:gender].present?
      relation = relation.where("voters.house_no ILIKE ?", like_pattern(params[:house_no])) if params[:house_no].present?
      relation = filter_voters_by_name(relation) if params[:name].present?
      @pagy, @voters = pagy(:offset, relation)
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
      if @booth.destroy
        redirect_to console_booths_path, notice: "Booth deleted."
      else
        redirect_to console_booths_path, alert: deletion_failure_message(@booth)
      end
    rescue ActiveRecord::InvalidForeignKey
      redirect_to console_booths_path, alert: deletion_failure_message(@booth)
    end

    private

    def set_booth
      @booth = Booth.find(params[:id])
    end

    def booth_params
      params.require(:booth).permit(:village_id, :number)
    end

    def booth_filters
      params.permit(:booth_number, :district_id, :taluka_id, :village_id).to_h
    end

    def voter_filters
      params.permit(:voter_id, :name, :age, :gender, :house_no).to_h
    end

    def filter_voters_by_name(relation)
      term = params[:name].strip.downcase
      ids = relation.filter_map { |voter| voter.id if voter_name(voter).include?(term) }
      Voter.where(id: ids).order(:id)
    end

    def voter_name(voter)
      [ voter.first_name, voter.middle_name, voter.last_name ].compact.join(" ").downcase
    end

    def like(value)
      ActiveRecord::Base.sanitize_sql_like(value.strip)
    end

    def like_pattern(value)
      "%#{like(value)}%"
    end
  end
end
