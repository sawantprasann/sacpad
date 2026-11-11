class CleanupPendingConnectionsJob < ApplicationJob
  queue_as :default

  def perform
    ActsAsTenant.without_tenant do
      SocialMedia::PendingConnection.expired.delete_all
    end
  end
end
