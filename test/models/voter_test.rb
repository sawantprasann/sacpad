require "test_helper"

# Story 0.15 — the Voter primitive (v2): GLOBAL electoral-roll record, PII-encrypted, Tier-1 versioning.
# Sentiment tracking moved to org-scoped VoterSentiment model.
class VoterTest < ActiveSupport::TestCase
  test "PII is encrypted at rest but readable through the model" do
    voter = Voter.create!(voter_id: "X9", first_name: "Secret", last_name: "Name", mobile: "9999")
    raw = Voter.connection.select_one("SELECT first_name, voter_id FROM voters WHERE id = #{voter.id}")
    assert_not_equal "Secret", raw["first_name"], "first_name column must be ciphertext at rest"
    assert_equal "Secret", voter.reload.first_name, "model decrypts transparently"
  end

  test "deterministic voter_id is queryable (loose Ticket lookup key)" do
    Voter.create!(voter_id: "VID123", first_name: "A", last_name: "Test")
    assert Voter.find_by(voter_id: "VID123"), "deterministic encryption allows lookup by voter_id"
  end

  test "name search matches each word and can skip the middle name" do
    voter = Voter.new(first_name: "Tanaji", middle_name: "Jayvant", last_name: "Savant")

    assert voter.matches_name?("tanaji savant")
    assert voter.matches_name?("Savant Tanaji")
    assert voter.matches_name?("tanaji jayvant savant")
    assert_not voter.matches_name?("tanaji patil")
    assert_not voter.matches_name?("   ")
  end

  test "name joins the stored name parts and skips a blank middle name" do
    with_middle = Voter.new(first_name: "Asha", middle_name: "Ramesh", last_name: "Patil")
    assert_equal "Asha Ramesh Patil", with_middle.name

    without_middle = Voter.new(first_name: "Asha", middle_name: "", last_name: "Patil")
    assert_equal "Asha Patil", without_middle.name
  end

  test "roll order is booth number then serial" do
    village = State.create!(name: "Maharashtra").loksabhas.create!(name: "Baramati").assemblies.create!(name: "Indapur").villages.create!(name: "Nimgaon")
    booth_two = village.booths.create!(number: "2")
    booth_ten = village.booths.create!(number: "10")
    booth_letter = village.booths.create!(number: "B-12")
    late = Voter.create!(voter_id: "ROLL000003", first_name: "Late", last_name: "Two", sr_no: 3, booth: booth_two, village: village)
    early_ten = Voter.create!(voter_id: "ROLL000010", first_name: "Early", last_name: "Ten", sr_no: 1, booth: booth_ten, village: village)
    first = Voter.create!(voter_id: "ROLL000001", first_name: "First", last_name: "Two", sr_no: 1, booth: booth_two, village: village)
    letter = Voter.create!(voter_id: "ROLL0000B", first_name: "Letter", last_name: "Booth", sr_no: 1, booth: booth_letter, village: village)
    missing_booth = Voter.create!(voter_id: "ROLL0000N", first_name: "No", last_name: "Booth", sr_no: 1, village: village)
    blank_serial = Voter.create!(voter_id: "ROLL0000X", first_name: "Blank", last_name: "Serial", booth: booth_two, village: village)

    ordered = Voter.by_booth_and_serial.where(village: village).pluck(:id)
    assert_equal [ first, late, blank_serial, early_ten, letter, missing_booth ].map(&:id), ordered
  end

  test "Tier-1 versioning records a dedicated VoterVersion on change" do
    v = Voter.create!(voter_id: "V1", first_name: "A", last_name: "Test")
    assert_difference -> { VoterVersion.where(item_id: v.id).count }, 1 do
      v.update!(first_name: "B")
    end
  end
end
