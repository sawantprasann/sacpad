# Org-side voter management (Epic 6 — Voter Lists, org-scoped sentiment tracking)
class VotersController < ApplicationController
  before_action :authenticate_user!
  before_action :set_voter, only: [:show, :update_sentiment]
  helper_method :voter_filters

  def index
    relation = Voter.all
    if params[:q].present?
      search_term = "%#{params[:q]}%"
      relation = relation.where("voter_id ILIKE ? OR first_name ILIKE ? OR last_name ILIKE ? OR middle_name ILIKE ?",
                               search_term, search_term, search_term, search_term)
    end
    if params[:village].present?
      relation = relation.joins(:village).where("villages.name ILIKE ?", "%#{like(params[:village])}%")
    end
    if params[:sentiment].present?
      org_sentiment = VoterSentiment.where(organization_id: current_organization.id, sentiment_status: params[:sentiment])
      relation = relation.joins(:voter_sentiments).where(voter_sentiments: { id: org_sentiment.select(:id) })
    end

    @pagy, @voters = pagy(:offset, relation.order(created_at: :desc))
    @search_hint = "Showing recently added voters." if voter_filters.values.all?(&:blank?)
  end

  def show
    @voter_sentiment = ActsAsTenant.with_tenant(current_organization) do
      VoterSentiment.find_or_create_by(voter_id: @voter.id, organization_id: current_organization.id)
    end
  end

  def update_sentiment
    @voter_sentiment = ActsAsTenant.with_tenant(current_organization) do
      VoterSentiment.find_or_create_by(voter_id: @voter.id, organization_id: current_organization.id)
    end

    if @voter_sentiment.update(
      sentiment_status: params[:sentiment_status],
      sentiment_updated_by_id: current_user.id,
      sentiment_updated_at: Time.current
    )
      redirect_to voter_path(@voter), notice: "Sentiment updated."
    else
      redirect_to voter_path(@voter), alert: "Failed to update sentiment."
    end
  end

  private

  def set_voter
    @voter = Voter.find(params[:id])
  end

  def voter_filters
    params.permit(:q, :village, :sentiment).to_h
  end

  def like(value)
    ActiveRecord::Base.sanitize_sql_like(value.strip)
  end

  def current_organization
    current_user.organization
  end
end
