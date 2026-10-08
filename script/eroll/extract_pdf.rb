#!/usr/bin/env ruby

require "net/http"
require "uri"
require "fileutils"
require "pdf-reader"
require "csv"
require "tempfile"
require "open3"
require "json"

URL_TEMPLATE = "https://voters.eci.gov.in/eroll/2026/s13/sir-draftroll/255/2026-EROLLGEN-S13-255-SIR-DraftRoll-Revision1-ENG-%<part_no>d-WI.pdf"
SAVE_DIRECTORY = "./erolls_255_test"
CSV_FILENAME = "voter_list_255_test.csv"
MAX_PARTS = 2
SKIP_PAGES = 2

EPIC_RE = /\A[A-Z]{3}\d{7}\z/
SERIAL_RE = /\A\d{1,4}\z/
VOTER_HEADERS = [ "Part No", "Serial No", "EPIC", "Elector Name", "Relative Name", "House No", "Age", "Gender" ].freeze
COVER_HEADERS = [
  "Main Town or Village",
  "Police Station",
  "Taluka",
  "District",
  "Pin Code",
  "Polling Station No. and Name",
  "Polling Station Address",
  "Type of Polling Station",
  "Starting Serial No.",
  "Ending Serial No.",
  "Male Electors",
  "Female Electors",
  "Third Gender Electors",
  "Total Net Electors",
  "Assembly Constituency No.",
  "Assembly Constituency Name",
  "Parliamentary Constituency No.",
  "Parliamentary Constituency Name",
  "Male",
  "Female"
].freeze
OCR_SRC = File.expand_path("ocr_page.swift", __dir__)
OCR_BIN = File.expand_path("ocr_page", __dir__)

def ensure_ocr_bin!
  if !File.exist?(OCR_BIN) || File.mtime(OCR_SRC) > File.mtime(OCR_BIN)
    swiftc = ENV.fetch("PATH", "").split(File::PATH_SEPARATOR).any? { |dir| File.executable?(File.join(dir, "swiftc")) }
    abort "swiftc is required to build the roll OCR helper (#{OCR_SRC})" unless swiftc
    warn "Compiling OCR helper..."
    ok = system("swiftc", "-O", "-o", OCR_BIN, OCR_SRC)
    abort "Failed to compile #{OCR_SRC}" unless ok
  end
  OCR_BIN
end

def norm_space(text)
  text.to_s.gsub(/\s+/, " ").strip
end

def canon_gender(text)
  case text.to_s.strip
  when /\Ama/i then "Male"
  when /\Af/i then "Female"
  when /\At/i then "Third Gender"
  when /\AM\z/i then "Male"
  when /\AF\z/i then "Female"
  else text.to_s.strip
  end
end

def detach_house(relative, house)
  text = relative.to_s
  if (match = text.match(/\A(.+?)\s+\S{0,4}(?:ouse|use)\s*Number\s*:?\s*(\S.*?)\s*\z/i))
    text = match[1].sub(/[:\s\-–]+\z/, "")
    house = norm_space(match[2]) if house.nil? || house == "N/A"
  elsif (match = text.match(/\A(.+?)\s+:\s*(\d[\d\-\/A-Za-z]*)\s*(?:House\s*)?Number\s*\z/i))
    text = match[1].sub(/[:\s\-–]+\z/, "")
    house = norm_space(match[2]) if house.nil? || house == "N/A"
  end
  text = "N/A" if text.empty?
  [ text, house ]
end

def canon_relative(label, value)
  name = norm_space(value)
  prefix = if label.match?(/husb|usband|sband|lusband/i)
    "Husband's Name"
  elsif label.match?(/mother|mothe/i)
    "Mother's Name"
  elsif label.match?(/other/i)
    "Others Name"
  else
    "Father's Name"
  end
  name.empty? ? prefix : "#{prefix}: #{name}"
end

def page_jpeg(page)
  images = page.xobjects.values.select { |obj| obj.hash[:Subtype] == :Image }
  image = images.max_by { |obj| obj.hash[:Width].to_i * obj.hash[:Height].to_i }
  return nil unless image

  data = image.data
  return nil unless data && data.bytesize > 1000 && data.bytes[0, 2] == [ 0xFF, 0xD8 ]
  data
end

def ocr_boxes(image_path)
  stdout, status = Open3.capture2(OCR_BIN, image_path)
  abort "OCR failed for #{image_path}" unless status.success?

  stdout.each_line.filter_map do |line|
    x, y, w, h, text = line.strip.split("\t", 5)
    next if text.nil? || text.empty?
    { x: x.to_f, y: y.to_f, w: w.to_f, h: h.to_f, text: norm_space(text) }
  end
end

def serial_needs_reread?(record, records)
  return true if record[:serial].nil?

  numbers = records.filter_map { |item| item[:serial]&.to_i }.select(&:positive?)
  return false if numbers.size < 3

  median = numbers.sort[numbers.size / 2]
  median >= 20 && record[:serial].to_i < 10
end

def fill_missing_serials(image_path, records)
  missing = records.select { |record| serial_needs_reread?(record, records) }
  return if missing.empty?

  jobs = missing.map do |record|
    epic = record[:epic_box]
    [
      record[:epic],
      format("%.5f", epic[:x] - 0.165),
      format("%.5f", epic[:y] - 0.010),
      "0.09000",
      "0.03000"
    ].join("\t")
  end

  stdout, status = Open3.capture2(OCR_BIN, image_path, "--serials", stdin_data: jobs.join("\n") + "\n")
  unless status.success?
    warn "Serial OCR failed for #{image_path}"
    return
  end

  found = {}
  stdout.each_line do |line|
    epic, serial = line.strip.split("\t", 2)
    found[epic] = serial if serial && serial.match?(SERIAL_RE)
  end
  missing.each do |record|
    record[:serial] = found[record[:epic]] if found[record[:epic]]
  end
end

def reread_cards(image_path, epics)
  return [] if epics.empty?

  jobs = epics.map do |epic|
    x = [ epic[:x] - 0.245, 0 ].max
    y = [ epic[:y] - 0.060, 0 ].max
    [ epic[:text], format("%.5f", x), format("%.5f", y), "0.22500", "0.05800" ].join("\t")
  end
  stdout, status = Open3.capture2(OCR_BIN, image_path, "--lines", stdin_data: "#{jobs.join("\n")}\n")
  unless status.success?
    warn "Card reread failed for #{image_path}"
    return []
  end

  grouped = Hash.new { |hash, key| hash[key] = [] }
  cursor = Hash.new(1.0)
  stdout.each_line do |line|
    epic, text = line.strip.split("\t", 2)
    next if epic.nil? || text.nil? || text.empty?

    cursor[epic] -= 0.01
    grouped[epic] << { x: 0.1, y: cursor[epic], w: 0.2, h: 0.01, text: norm_space(text) }
  end

  epics.filter_map do |epic|
    lines = grouped[epic[:text]]
    next if lines.empty?

    parse_card(epic, lines)
  end
end

def label_pieces(text)
  text.split(
    /(?=(?:House\s*Number|Age\s*:|[A-Za-z]{0,3}(?:ather|ther|usband|sband|other)['’]?\s*s?\s*Name)\b)/i
  ).map { |part| norm_space(part) }.reject(&:empty?)
end

def apply_field(text, state)
  if (match = text.match(/\A\S{0,10}(?:father|husband|mother|others|ather|ther|usband|sband|lusband|mothe).{0,8}Name\s*:\s*(.*)\z/i))
    state[:relative] = canon_relative(match[0], match[1])
    state[:target] = :relative
    return true
  end

  if (match = text.match(/\A\S{0,4}ouse\s*Number\s*:\s*(.*)\z/i))
    state[:house] = norm_space(match[1])
    state[:target] = :house
    return true
  end

  if (match = text.match(/\A[A-Za-z]{0,3}\s*:?\s*(\d+)\s*\S+\s*:?\s*([A-Za-z]+)\z/i)) && text.match?(/ge|gender|gend/i)
    state[:age] = match[1]
    state[:gender] = canon_gender(match[2])
    state[:target] = nil
    return true
  end

  if (match = text.match(/\A(?:[A-Za-z]{0,3}ame|[A-Za-z]?me)\s*:\s*(.*)\z/i))
    state[:name] = norm_space(match[1]).sub(/[\s\-–]+$/, "")
    state[:target] = :name
    return true
  end

  false
end

def parse_card(epic, lines)
  serial = nil
  state = { name: nil, relative: nil, house: nil, age: nil, gender: nil, target: nil }

  lines.sort_by { |box| -box[:y] }.each do |box|
    text = box[:text]
    next if text.empty?
    next if text.match?(/\A(Photo|Available)\z/i)
    next if text.match?(/\A(Age as on|Date of Publication|Total Pages|Assembly Constituency|Section No|Part No)\b/i)
    next if text.match?(EPIC_RE)

    if text.match?(SERIAL_RE) && (box[:y] - epic[:y]).abs < 0.02
      serial = text
      next
    end

    pieces = label_pieces(text)
    consumed = false
    pieces.each { |piece| consumed = true if apply_field(piece, state) }
    next if consumed

    case state[:target]
    when :name then state[:name] = norm_space("#{state[:name]} #{text}")
    when :relative then state[:relative] = norm_space("#{state[:relative]} #{text}")
    when :house then state[:house] = norm_space("#{state[:house]} #{text}")
    end
  end

  name = state[:name]
  relative = state[:relative]
  house = state[:house]
  age = state[:age]
  gender = state[:gender]

  return nil if name.nil? || name.empty? || age.nil?

  house = nil if house.to_s.empty?
  house = house.gsub(/\s+/, "") if house&.match?(/\A[\d\s]+\z/)
  relative, house = detach_house(relative || "N/A", house || "N/A")
  house = house.gsub(/\s+/, "") if house&.match?(/\A[\d\s]+\z/)
  {
    serial: serial,
    epic: epic[:text],
    epic_box: epic,
    x: epic[:x],
    y: epic[:y],
    name: name,
    relative: relative || "N/A",
    house: house || "N/A",
    age: age,
    gender: gender
  }
end

def cards_from_boxes(boxes)
  epics = boxes.select { |box| box[:text].match?(EPIC_RE) }
  return [] if epics.empty?

  columns = []
  epics.sort_by { |epic| epic[:x] }.each do |epic|
    column = columns.find { |group| (group.first[:x] - epic[:x]).abs < 0.06 }
    column ? column << epic : columns << [ epic ]
  end

  regions = columns.flat_map do |column|
    column.sort_by! { |epic| -epic[:y] }
    column.each_with_index.map do |epic, index|
      next_epic = column[index + 1]
      {
        epic: epic,
        x_left: epic[:x] - 0.25,
        x_right: epic[:x] + epic[:w] + 0.01,
        y_top: [ epic[:y] + epic[:h] + 0.014, 0.967 ].min,
        y_bottom: next_epic ? next_epic[:y] + next_epic[:h] + 0.004 : 0.02
      }
    end
  end

  grouped = Hash.new { |hash, key| hash[key] = [] }
  boxes.each do |box|
    cy = box[:y] + (box[:h] / 2.0)
    matches = regions.select do |region|
      box[:x] >= region[:x_left] && box[:x] <= region[:x_right] && cy <= region[:y_top] && cy >= region[:y_bottom]
    end
    next if matches.empty?

    region = matches.min_by { |item| (item[:epic][:y] - box[:y]).abs }
    grouped[region[:epic]] << box
  end

  grouped.filter_map { |epic, lines| parse_card(epic, lines) }
end

def repair_serials!(records)
  records.each_with_index do |record, index|
    prev = index.positive? ? records[index - 1] : nil
    nxt = records[index + 1]
    next unless prev && nxt

    previous_serial = prev[:serial].to_i
    next_serial = nxt[:serial].to_i
    current_serial = record[:serial].to_i
    next unless previous_serial.positive? && next_serial > previous_serial && (next_serial - previous_serial) <= 3

    expected = previous_serial + 1
    next if current_serial == expected
    next if current_serial > previous_serial && current_serial < next_serial

    record[:serial] = expected.to_s
  end
end

def sort_records(records)
  rows = []
  records.sort_by { |record| -record[:y] }.each do |record|
    if rows.empty? || (rows.last.first[:y] - record[:y]) > 0.03
      rows << [ record ]
    else
      rows.last << record
    end
  end
  rows.flat_map { |row| row.sort_by { |record| record[:x] } }
end

def clean_cover_value(text)
  norm_space(text).sub(/\A[:\s]+/, "")
end

def cover_label(boxes, regex, y_range = 0.05..0.98)
  boxes.find { |box| box[:y].between?(y_range.begin, y_range.end) && box[:text].match?(regex) }
end

def value_right_of(boxes, label)
  return "" unless label

  candidates = boxes.select { |box| box[:x] > label[:x] + 0.08 && (box[:y] - label[:y]).abs < 0.016 }
  best = candidates.min_by { |box| (box[:y] - label[:y]).abs }
  return "" unless best

  candidates
    .select { |box| (box[:y] - best[:y]).abs < 0.004 }
    .sort_by { |box| box[:x] }
    .map { |box| box[:text] }
    .join(" ")
    .then { |text| clean_cover_value(text) }
end

def number_below(boxes, label)
  return "" unless label

  match = boxes
    .select do |box|
      box[:text].match?(/\A\d+\z/) &&
        box[:y] < label[:y] - 0.008 &&
        box[:y] > label[:y] - 0.07 &&
        (box[:x] - label[:x]).abs < 0.09
    end
    .min_by { |box| (box[:x] - label[:x]).abs }
  match ? match[:text] : ""
end

def constituency_parts(boxes, label_regex)
  label = boxes.find { |box| box[:text].match?(label_regex) }
  return [ "", "" ] unless label

  text = label[:text]
  follow = boxes
    .select do |box|
      box[:y] < label[:y] && box[:y] > label[:y] - 0.025 && box[:x] < 0.25 &&
        !box[:text].match?(/Details|Year|Revision|Parliamentary|Assembly/i)
    end
    .sort_by { |box| -box[:y] }
  text = "#{text} #{follow.map { |box| box[:text] }.join(" ")}"
  match = text.match(/:\s*(\d+)\s*-\s*([A-Za-z][A-Za-z ]*?)(?:\s*\(|\s*$)/)
  return [ "", "" ] unless match

  [ match[1], norm_space(match[2]) ]
end

def parse_cover(boxes)
  meta = COVER_HEADERS.to_h { |header| [ header, "" ] }
  meta["Main Town or Village"] = value_right_of(boxes, cover_label(boxes, /\AMain Town or Village\z/i))
  meta["Police Station"] = value_right_of(boxes, cover_label(boxes, /\APolice Station\z/i))
  meta["Taluka"] = value_right_of(boxes, cover_label(boxes, /\ATaluka\z/i))
  meta["District"] = value_right_of(boxes, cover_label(boxes, /\ADistrict\z/i))
  meta["Pin Code"] = value_right_of(boxes, cover_label(boxes, /\APin code\z/i))
  meta["Type of Polling Station"] = value_right_of(boxes, cover_label(boxes, /\AType of Polling Station\z/i))

  station = cover_label(boxes, /No\. and Name of Polling Station/i)
  address = cover_label(boxes, /Address of Polling Station/i)
  electors = cover_label(boxes, /NUMBER OF ELECTORS/i)
  if station && address
    meta["Polling Station No. and Name"] = boxes
      .select { |box| box[:x] < 0.4 && box[:y] < station[:y] - 0.008 && box[:y] > address[:y] + 0.012 }
      .sort_by { |box| -box[:y] }
      .map { |box| box[:text] }
      .join(" ")
      .then { |text| clean_cover_value(text) }
  end
  if address && electors
    meta["Polling Station Address"] = boxes
      .select { |box| box[:x] < 0.5 && box[:y] < address[:y] - 0.008 && box[:y] > electors[:y] + 0.012 }
      .sort_by { |box| -box[:y] }
      .map { |box| clean_cover_value(box[:text]) }
      .reject(&:empty?)
      .join(" ")
  end

  meta["Starting Serial No."] = number_below(boxes, cover_label(boxes, /\AStarting\z/i, 0.15..0.4))
  meta["Ending Serial No."] = number_below(boxes, cover_label(boxes, /\AEnding\z/i, 0.15..0.4))
  meta["Male Electors"] = number_below(boxes, cover_label(boxes, /\AMale\z/i, 0.15..0.4))
  meta["Female Electors"] = number_below(boxes, cover_label(boxes, /\AFemale\z/i, 0.15..0.4))
  meta["Third Gender Electors"] = number_below(boxes, cover_label(boxes, /\AThird Gender\z/i, 0.15..0.4))
  meta["Total Net Electors"] = number_below(boxes, cover_label(boxes, /\ATotal\z/i, 0.15..0.4))
  meta["Male"] = meta["Male Electors"]
  meta["Female"] = meta["Female Electors"]

  assembly_no, assembly_name = constituency_parts(boxes, /Assembly Constituency/i)
  parliament_no, parliament_name = constituency_parts(boxes, /Parliamentary Constituency/i)
  meta["Assembly Constituency No."] = assembly_no
  meta["Assembly Constituency Name"] = assembly_name
  meta["Parliamentary Constituency No."] = parliament_no
  meta["Parliamentary Constituency Name"] = parliament_name
  meta
end

def cover_metadata(reader)
  jpeg = page_jpeg(reader.pages[0])
  return COVER_HEADERS.to_h { |header| [ header, "" ] } unless jpeg

  image = Tempfile.new([ "eroll-cover", ".jpg" ])
  begin
    image.binmode
    image.write(jpeg)
    image.close
    parse_cover(ocr_boxes(image.path))
  ensure
    image.close!
  end
end

def voters_from_reader(reader)
  part_records = []
  reader.pages.each_with_index do |page, index|
    next if index < SKIP_PAGES

    jpeg = page_jpeg(page)
    if jpeg.nil?
      warn "  Page #{index + 1}: no page image, skipped"
      next
    end

    image = Tempfile.new([ "eroll-p#{index + 1}", ".jpg" ])
    begin
      image.binmode
      image.write(jpeg)
      image.close

      boxes = ocr_boxes(image.path)
      records = cards_from_boxes(boxes)
      found_epics = records.map { |record| record[:epic] }
      missed = boxes.select { |box| box[:text].match?(EPIC_RE) && !found_epics.include?(box[:text]) }
      records.concat(reread_cards(image.path, missed))
      records = sort_records(records)
      fill_missing_serials(image.path, records)

      part_records.concat(records)
      warn "  Page #{index + 1}: #{records.length} voters"
    ensure
      image.close!
    end
  end

  repair_serials!(part_records)
  part_records
end

def extract_pdf(path)
  ensure_ocr_bin!
  reader = PDF::Reader.new(path)
  { cover: cover_metadata(reader), voters: voters_from_reader(reader) }
end

def download_part(part_no, filepath)
  url_string = format(URL_TEMPLATE, part_no: part_no)
  uri = URI.parse(url_string)
  response = Net::HTTP.start(uri.host, uri.port, use_ssl: true) do |http|
    http.request(Net::HTTP::Get.new(uri))
  end

  code = response.code.to_i
  if code == 404
    puts "[404 NOT FOUND] Stopped."
    return :missing
  end
  unless code == 200
    puts "[DOWNLOAD FAILED] HTTP #{code}"
    return :failed
  end

  File.binwrite(filepath, response.body)
  puts "[DOWNLOAD SUCCESS] Saved to #{filepath}"
  :downloaded
end

def run!
  ensure_ocr_bin!
  FileUtils.mkdir_p(SAVE_DIRECTORY)

  CSV.open(CSV_FILENAME, "w", write_headers: true, headers: VOTER_HEADERS + COVER_HEADERS) do |csv|
    (1..MAX_PARTS).each do |part_no|
      filepath = File.join(SAVE_DIRECTORY, "Part_#{part_no}.pdf")
      puts "\n========================================================"
      puts "Part #{part_no} of #{MAX_PARTS}"
      puts "========================================================"

      if File.exist?(filepath) && File.size(filepath) > 1000
        puts "[LOCAL] Using #{filepath}"
      else
        result = download_part(part_no, filepath)
        break if result == :missing
        next if result == :failed
        sleep 0.5
      end

      reader = PDF::Reader.new(filepath)
      cover = cover_metadata(reader)
      puts "  Town: #{cover["Main Town or Village"]} | PS: #{cover["Polling Station No. and Name"]} | Electors: #{cover["Total Net Electors"]}"
      part_records = voters_from_reader(reader)
      part_records.each do |record|
        serial = record[:serial] || "N/A"
        puts "  [Part #{part_no}] Sr ##{serial} | EPIC: #{record[:epic]} | Name: #{record[:name]} | #{record[:relative]} | House: #{record[:house]} | Age: #{record[:age]} | Gender: #{record[:gender]}"
        csv << [
          part_no, serial, record[:epic], record[:name], record[:relative], record[:house], record[:age], record[:gender],
          *COVER_HEADERS.map { |header| cover[header] }
        ]
      end
      puts "--> Part #{part_no} complete: #{part_records.length} voter entries."
    end
  end
end

if __FILE__ == $PROGRAM_NAME
  pdf_flag = ARGV.index("--pdf")
  if pdf_flag
    pdf_path = ARGV[pdf_flag + 1]
    abort "Pass a PDF path after --pdf" if pdf_path.nil? || !File.file?(pdf_path)

    result = extract_pdf(pdf_path)
    puts JSON.generate(
      "cover" => result[:cover],
      "voters" => result[:voters].map do |record|
        {
          "serial" => record[:serial],
          "epic" => record[:epic],
          "name" => record[:name],
          "relative" => record[:relative],
          "house" => record[:house],
          "age" => record[:age],
          "gender" => record[:gender]
        }
      end
    )
  else
    run!
  end
end
