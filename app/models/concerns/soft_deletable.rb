# Soft-delete convention (§3.4a): no domain data is ever hard-deleted. Including models'
# migrations must add `discarded_at` (datetime) and `discarded_by_id` (bigint). PaperTrail (when
# also included) sees a discard as an ordinary tracked update, so history survives archiving.
module SoftDeletable
  extend ActiveSupport::Concern

  included do
    include Discard::Model
  end

  # Soft-delete and record who did it (User or Admin id).
  def discard_by(actor)
    self.discarded_by_id = actor&.id
    discard
  end
end
