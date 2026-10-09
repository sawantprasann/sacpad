namespace :eroll do
  desc "Fetch a Lok Sabha's assemblies and/or queue one assembly's roll PDFs. Pass LOKSABHA_ID, ASSEMBLY_ID, or both. FIRST_PART and LAST_PART set that assembly's PDF range."
  task :import, [ :loksabha_id, :assembly_id ] => :environment do |_task, args|
    loksabha_id = args[:loksabha_id].presence || ENV["LOKSABHA_ID"].presence
    assembly_id = args[:assembly_id].presence || ENV["ASSEMBLY_ID"].presence
    first_part = ENV["FIRST_PART"].presence
    last_part = ENV["LAST_PART"].presence
    abort "Pass LOKSABHA_ID, ASSEMBLY_ID, or both." if loksabha_id.blank? && assembly_id.blank?
    abort "Pass ASSEMBLY_ID with FIRST_PART and LAST_PART." if assembly_id.blank? && (first_part || last_part)
    abort "Pass both FIRST_PART and LAST_PART." if first_part.blank? ^ last_part.blank?

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
      assembly.update!(first_part: first_part, last_part: last_part) if first_part && last_part
      if assembly.first_part.blank? || assembly.last_part.blank?
        abort "Pass FIRST_PART and LAST_PART for #{assembly.name}."
      end

      ImportAssemblyVotersJob.perform_later(assembly.id)
      count = assembly.last_part - assembly.first_part + 1
      puts "Queued #{count} roll PDFs for #{assembly.name} (parts #{assembly.first_part}–#{assembly.last_part}). bin/jobs reads #{ImportAssemblyVotersJob::PARTS_AT_A_TIME} at a time."
    end
  end
end
