module Console
  # Platform operational health (§5a, Story 0.13): background-job/queue health + external-provider
  # headroom. Metrics are gathered defensively — the sync jobs and Meta/WhatsApp/IVRS integrations
  # arrive in later epics, so their panels show placeholders until then.
  class PlatformHealthController < BaseController
    def show
      stats = sidekiq_stats
      @queue_depth = stats&.enqueued
      @failed_jobs = stats && (stats.retry_size + stats.dead_size)
      @org_count    = Organization.count
      @active_orgs  = Organization.active.count
      # Daily Meta sync + token headroom land with Epic 5; surfaced as pending for now.
      @sync_status  = "No sync jobs configured yet (Epic 5)"
      @token_status = "No external integrations connected yet (Epic 5)"
    end

    private

    def sidekiq_stats
      return if Rails.env.test?

      Sidekiq::Stats.new
    rescue StandardError
      nil
    end
  end
end
