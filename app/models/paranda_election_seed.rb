class ParandaElectionSeed
  # Published Paranda assembly results. Re-running replaces the candidate lines
  # for these two years and leaves every other constituency alone.
  def self.load!
    assembly = find_or_create_assembly
    parties = parties_by_abbreviation

    RESULTS.each do |attrs|
      candidates = attrs.fetch(:candidates).map do |row|
        row.merge(party: parties.fetch(row.fetch(:party)))
      end
      store(assembly, attrs.except(:candidates), candidates, parties)
    end
  end

  RESULTS = [
    {
      year: 2024,
      title: "2024 Maharashtra Legislative Assembly election : Paranda",
      outcome: :hold,
      swing: -5.76,
      margin_votes: 1_509,
      margin_percent: 0.65,
      margin_change: -14.79,
      turnout_votes: 233_715,
      turnout_percent: 70.49,
      turnout_change: 2.18,
      valid_votes: 233_027,
      registered_electors: 331_546,
      electors_change: 5.35,
      candidates: [
        { party: "SS", candidate_name: "Dr. Tanaji Jayawant Sawant", votes: 103_254, vote_percent: 44.31, vote_change: -5.76, winner: true },
        { party: "NCP-SP", candidate_name: "Rahul Maharudra Mote", votes: 101_745, vote_percent: 43.66, new_contestant: true },
        { party: "VBA", candidate_name: "Pravin Parmeshwar Ranbagul", votes: 12_698, vote_percent: 5.45, vote_change: -7.66 },
        { party: "Independent", candidate_name: "Jameelkha Mahebub Pathan", votes: 4_446, vote_percent: 1.91, new_contestant: true },
        { party: "RSPS", candidate_name: "Dr. Rahul Bhimrao Ghule", votes: 2_170, vote_percent: 0.93, new_contestant: true },
        { party: "NOTA", candidate_name: "None of the above", votes: 688, vote_percent: 0.30, vote_change: -0.59 }
      ]
    },
    {
      year: 2019,
      title: "2019 Maharashtra Legislative Assembly election : Paranda",
      outcome: :gain,
      gained_from: "NCP",
      swing: 9.99,
      margin_votes: 32_902,
      margin_percent: 15.44,
      margin_change: 9.12,
      turnout_votes: 214_975,
      turnout_percent: 68.31,
      turnout_change: -1.47,
      valid_votes: 213_064,
      registered_electors: 314_711,
      electors_change: 6.68,
      candidates: [
        { party: "SS", candidate_name: "Dr. Tanaji Jayawant Sawant", votes: 106_674, vote_percent: 50.07, vote_change: 16.31, winner: true },
        { party: "NCP", candidate_name: "Rahul Maharudra Mote", votes: 73_772, vote_percent: 34.62, vote_change: -5.46 },
        { party: "VBA", candidate_name: "Suryakant (Suresh Bhau) Chandrakant Kamble", votes: 27_939, vote_percent: 13.11, new_contestant: true },
        { party: "NOTA", candidate_name: "None of the above", votes: 1_902, vote_percent: 0.89, vote_change: -0.30 }
      ]
    }
  ].freeze

  PARTIES = [
    [ "SS", "Shiv Sena", "#F97316" ],
    [ "NCP-SP", "Nationalist Congress Party (Sharadchandra Pawar)", "#1E3A8A" ],
    [ "NCP", "Nationalist Congress Party", "#00A3E0" ],
    [ "VBA", "Vanchit Bahujan Aghadi", "#2563EB" ],
    [ "RSPS", "Rashtriya Samaj Paksha", "#FACC15" ],
    [ "Independent", "Independent", "#9CA3AF" ],
    [ "NOTA", "None of the Above", "#E5E7EB" ]
  ].freeze

  class << self
    private

    def find_or_create_assembly
      Assembly.find_by(name: "Paranda", constituency_no: "243") ||
        Assembly.where("name ILIKE ?", "Paranda").order(:id).first ||
        build_assembly
    end

    def build_assembly
      state = State.find_or_create_by!(name: "Maharashtra")
      district = District.find_or_create_by!(state: state, name: "Dharashiv")
      loksabha = Loksabha.find_or_create_by!(state: state, name: "Osmanabad") do |record|
        record.district = district
      end
      loksabha.assemblies.create!(name: "Paranda", constituency_no: "243")
    end

    def parties_by_abbreviation
      PARTIES.to_h do |abbreviation, name, color|
        party = Party.find_or_create_by!(abbreviation: abbreviation) do |record|
          record.name = name
          record.color = color
        end
        [ abbreviation, party ]
      end
    end

    def store(assembly, attrs, candidates, parties)
      attrs = attrs.dup
      gained_from = attrs.delete(:gained_from)
      election = ConstituencyElection.find_or_initialize_by(constituency: assembly, year: attrs.fetch(:year))
      election.assign_attributes(attrs.except(:year))
      election.gained_from_party = gained_from.present? ? parties.fetch(gained_from) : nil

      ConstituencyElection.transaction do
        if election.persisted?
          election.candidates.delete_all
          election.candidates.reset
        end
        candidates.each_with_index do |row, index|
          election.candidates.build(row.merge(position: index + 1))
        end
        election.save!
      end
    end
  end
end
