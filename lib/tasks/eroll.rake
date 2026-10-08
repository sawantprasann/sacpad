namespace :eroll do
  desc "Fetch a Lok Sabha roll and/or queue one assembly's voter sync. Pass LOKSABHA_ID, ASSEMBLY_ID, or both."
  task :import, [ :loksabha_id, :assembly_id ] => :environment do |_task, args|
    loksabha_id = args[:loksabha_id].presence || ENV["LOKSABHA_ID"].presence
    assembly_id = args[:assembly_id].presence || ENV["ASSEMBLY_ID"].presence
    abort "Pass LOKSABHA_ID, ASSEMBLY_ID, or both." if loksabha_id.blank? && assembly_id.blank?

    loksabha = Loksabha.find(loksabha_id) if loksabha_id
    assembly = Assembly.find(assembly_id) if assembly_id
    if loksabha && assembly && assembly.loksabha_id != loksabha.id
      abort "Assembly #{assembly.id} is not in Lok Sabha #{loksabha.id}."
    end

    if loksabha
      result = Eci::ImportLoksabha.new(loksabha, enqueue_voters: assembly.nil?).call
      puts result.summary(loksabha.name)
    end

    if assembly
      unless Booth.joins(:village).exists?(villages: { assembly_id: assembly.id })
        abort "Assembly #{assembly.id} has no booths yet."
      end

      ImportAssemblyVotersJob.perform_later(assembly.id)
      puts "Queued voter sync for #{assembly.name}. bin/jobs reads each booth PDF."
    end
  end
end
