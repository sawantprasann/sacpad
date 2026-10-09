# Queues one job per roll PDF in the assembly's first-to-last part range.
class ImportAssemblyVotersJob < ApplicationJob
  queue_as :default

  # bin/jobs runs this many part jobs at once. Keep config/queue.yml in step.
  PARTS_AT_A_TIME = 1

  def perform(assembly_id)
    assembly = Assembly.find(assembly_id)
    from = assembly.first_part
    to = assembly.last_part
    return if from.blank? || to.blank? || to < from

    (from..to).each do |part|
      ImportAssemblyPartJob.perform_later(assembly.id, part)
    end
  end
end
