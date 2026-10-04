module Console
  # Platform operational health (§5a, Story 0.13): background-job/queue health + external-provider
  # headroom. Metrics are gathered defensively — the sync jobs and Meta/WhatsApp/IVRS integrations
  # arrive in later epics, so their panels show placeholders until then.
  class PlatformHealthController < BaseController
    def show
      @queue_depth  = safe { SolidQueue::Job.where(finished_at: nil).count }
      @failed_jobs  = safe { SolidQueue::FailedExecution.count }
      @org_count    = Organization.count
      @active_orgs  = Organization.active.count
      # Daily Meta sync + token headroom land with Epic 5; surfaced as pending for now.
      @sync_status  = "No sync jobs configured yet (Epic 5)"
      @token_status = "No external integrations connected yet (Epic 5)"
    end

    private

    # Contain each probe in a savepoint so a failing query (e.g. Solid Queue tables living in a
    # separate database that isn't present in this environment) can't poison the request transaction.
    def safe
      ActiveRecord::Base.transaction(requires_new: true) { yield }
    rescue StandardError
      nil
    end
  end
end
