module Console
  class VillagesController < ReferenceController
    self.managed_model = Village
    self.managed_fields = %i[taluka_id name police_station pin_code]
    self.managed_title = "Village"

    prepend_before_action :set_parents
    skip_before_action :set_record
    before_action :set_record, only: %i[show edit update destroy]

    helper_method :voter_filters

    def show
      @voter_total = @record.voters.count
      relation = @record.voters.includes(:booth).order(:id)
      relation = relation.where(voter_id: params[:voter_id].strip) if params[:voter_id].present?
      if params[:age].present?
        age = Integer(params[:age], exception: false)
        relation = age ? relation.where(age: age) : relation.none
      end
      relation = relation.where("voters.gender ILIKE ?", like(params[:gender])) if params[:gender].present?
      relation = relation.where("voters.house_no ILIKE ?", like(params[:house_no])) if params[:house_no].present?
      if params[:booth].present?
        relation = relation.joins(:booth).where(booths: { number: params[:booth].strip })
      end
      relation = filter_voters_by_name(relation) if params[:name].present?
      @pagy, @voters = pagy(:offset, relation)
    end

    def new
      @record = @assembly.villages.new
      render "console/reference/new"
    end

    def create
      @record = @assembly.villages.new(record_params)
      if @record.save
        redirect_to console_loksabha_assembly_village_path(@loksabha, @assembly, @record), notice: "Village created."
      else
        render "console/reference/new", status: :unprocessable_entity
      end
    end

    def update
      if @record.update(record_params)
        redirect_to console_loksabha_assembly_village_path(@loksabha, @assembly, @record), notice: "Village updated."
      else
        render "console/reference/edit", status: :unprocessable_entity
      end
    end

    def destroy
      @record.destroy
      redirect_to console_loksabha_assembly_path(@loksabha, @assembly), notice: "Village deleted."
    rescue ActiveRecord::InvalidForeignKey, ActiveRecord::RecordNotDestroyed
      redirect_to console_loksabha_assembly_path(@loksabha, @assembly), alert: "Can't delete — it still has dependent records."
    end

    private

    def set_parents
      @loksabha = Loksabha.find(params[:loksabha_id])
      @assembly = @loksabha.assemblies.find(params[:assembly_id])
    end

    def set_record
      @record = @assembly.villages.includes(:taluka).find(params[:id])
    end

    def filter_voters_by_name(relation)
      term = params[:name].strip.downcase
      ids = relation.filter_map { |voter| voter.id if voter_name(voter).include?(term) }
      Voter.includes(:booth).where(id: ids).order(:id)
    end

    def voter_name(voter)
      [ voter.first_name, voter.middle_name, voter.last_name ].compact.join(" ").downcase
    end

    def voter_filters
      params.permit(:voter_id, :name, :age, :gender, :house_no, :booth)
    end

    def like(value)
      "%#{ActiveRecord::Base.sanitize_sql_like(value.strip)}%"
    end
  end
end
