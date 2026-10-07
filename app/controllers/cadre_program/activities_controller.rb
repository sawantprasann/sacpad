module CadreProgram
  # Cadre activity capture (Stories 2.1–2.2) plus the feed export (Story 2.3).
  # The dashboard widget and this list share policy_scope over cadre_activities.
  class ActivitiesController < ApplicationController
    before_action :authenticate_user!
    before_action :require_cadre_program_access

    def index
      authorize CadreActivity
      relation = filtered_activities
      respond_to do |format|
        format.html do
          @category_counts = relation.counts_by_category
          @pagy, @activities = pagy(:offset, with_list_includes(relation))
        end
        format.xlsx do
          @activities = with_list_includes(relation)
          response.headers["Content-Disposition"] = "attachment; filename=cadre_program_activities.xlsx"
        end
      end
    end

    def show
      @activity = policy_scope(CadreActivity).includes(
        :program, :leadership_meet, :party_program_hosted, :personal_activity, one_to_one: :karyakarta_user
      ).find(params[:id])
      authorize @activity
    end

    def new
      category = CadreActivity.categories.key?(params[:category]) ? params[:category] : nil
      @activity = CadreActivity.new(category: category)
      build_detail_shells
      load_org_users
      authorize @activity
    end

    def create
      @activity = CadreActivity.new(activity_params)
      @activity.owner = current_user
      authorize @activity
      if @activity.save
        record_activity("cadre_activity.created", record: @activity)
        redirect_to cadre_program_activity_path(@activity), notice: "Cadre activity logged."
      else
        build_detail_shells
        load_org_users
        render :new, status: :unprocessable_entity
      end
    end

    private

    def filtered_activities
      relation = policy_scope(CadreActivity)
      if params[:category].present? && CadreActivity.categories.key?(params[:category])
        @category_key = params[:category]
        @category_label = CadreActivity::CATEGORY_LABELS[@category_key]
        relation = relation.where(category: @category_key)
      end
      relation.order(created_at: :desc, id: :desc)
    end

    def with_list_includes(relation)
      relation.includes(
        :owner, :program, :leadership_meet, :party_program_hosted, :personal_activity, one_to_one: :karyakarta_user
      ).with_attached_photos
    end

    def activity_params
      params.require(:cadre_activity).permit(
        :category, :impact_notes, photos: [],
        program_attributes: %i[program_name occasion location occurred_on host notes],
        leadership_meet_attributes: %i[
          whom_to_meet point_of_discussion work_submitted submitted_on followup_on resolution_notes
        ],
        party_program_hosted_attributes: %i[
          program_name hosted_on location total_attendees print_media electronic_media
        ],
        personal_activity_attributes: %i[activity_name occasion total_submission from_date to_date notes],
        one_to_one_attributes: %i[
          karyakarta_user_id karyakarta_name_text assignment resolved from_date to_date notes
        ]
      )
    end

    # fields_for renders nothing until the association exists in memory. These shells are saved
    # only when that category's params come back on create.
    def build_detail_shells
      @activity.build_program unless @activity.program
      @activity.build_leadership_meet unless @activity.leadership_meet
      @activity.build_party_program_hosted unless @activity.party_program_hosted
      @activity.build_personal_activity unless @activity.personal_activity
      @activity.build_one_to_one unless @activity.one_to_one
    end

    def load_org_users
      @org_users = User.where(organization_id: current_user.organization_id).order(:name)
    end

    # Nav visibility is gated in the sidebar; access is also enforced here (not UI-only).
    def require_cadre_program_access
      return if current_user.role.can_access?("cadre_program")

      redirect_to root_path, alert: "You don't have access to Cadre Program."
    end
  end
end
