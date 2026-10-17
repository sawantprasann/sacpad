#!/usr/bin/env ruby
# Linux stand-in for the macOS Vision helper. Same interface:
#   ocr_page.rb <image>
#   ocr_page.rb <image> --serials   (stdin: id, x, y, w, h)
#   ocr_page.rb <image> --lines
# Boxes are Vision coordinates: origin at the bottom-left, values from 0 to 1.

require "open3"
require "tempfile"

image_path = ARGV[0]
mode = ARGV[1]
abort "usage: ocr_page <image> [--serials|--lines]" if image_path.nil? || image_path.empty?
abort "image not found: #{image_path}" unless File.file?(image_path)

def run!(*command)
  stdout, status = Open3.capture2(*command)
  abort "command failed: #{command.join(" ")}" unless status.success?

  stdout
end

def dimensions(path)
  width = run!("vipsheader", "-f", "width", path).to_i
  height = run!("vipsheader", "-f", "height", path).to_i
  abort "could not read image size" if width <= 0 || height <= 0

  [ width, height ]
end

def vision_box(left, top, width, height, image_width, image_height)
  {
    x: left.to_f / image_width,
    y: 1.0 - ((top + height).to_f / image_height),
    w: width.to_f / image_width,
    h: height.to_f / image_height
  }
end

def recognize_lines(path, psm:, whitelist: false)
  command = [ "tesseract", path, "stdout", "--psm", psm.to_s, "tsv" ]
  if whitelist
    command += [ "-c", "tessedit_char_whitelist=ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789" ]
  end
  stdout, status = Open3.capture2(*command)
  abort "tesseract failed for #{path}" unless status.success?

  words = []
  stdout.each_line.with_index do |line, index|
    next if index.zero?

    cols = line.chomp.split("\t", 12)
    next if cols.length < 12 || cols[0].to_i != 5

    text = cols[11].to_s.strip
    next if text.empty? || cols[10].to_f < 0

    words << {
      key: cols[1, 4],
      left: cols[6].to_i,
      top: cols[7].to_i,
      width: cols[8].to_i,
      height: cols[9].to_i,
      text: text
    }
  end

  words.group_by { |word| word[:key] }.map do |_key, group|
    left = group.map { |word| word[:left] }.min
    top = group.map { |word| word[:top] }.min
    right = group.map { |word| word[:left] + word[:width] }.max
    bottom = group.map { |word| word[:top] + word[:height] }.max
    {
      left: left,
      top: top,
      width: right - left,
      height: bottom - top,
      text: group.map { |word| word[:text] }.join(" ")
    }
  end
end

def pure_serial(lines)
  lines.each do |line|
    text = line[:text].to_s.strip
    next unless text.match?(/\A\d{1,4}\z/)
    next if text == "0"

    return text
  end
  nil
end

def crop(path, vx, vy, vw, vh)
  image_width, image_height = dimensions(path)
  x = (vx * image_width).floor
  y = ((1.0 - vy - vh) * image_height).floor
  width = (vw * image_width).round
  height = (vh * image_height).round
  x = 0 if x.negative?
  y = 0 if y.negative?
  width = image_width - x if x + width > image_width
  height = image_height - y if y + height > image_height
  return nil if width <= 2 || height <= 2

  file = Tempfile.new([ "eroll-crop", ".jpg" ])
  file.close
  File.unlink(file.path)
  _stdout, status = Open3.capture2("vips", "crop", path, file.path, x.to_s, y.to_s, width.to_s, height.to_s)
  return nil unless status.success? && File.file?(file.path)

  file
end

def upscale(path, factor)
  file = Tempfile.new([ "eroll-scale", ".jpg" ])
  file.close
  File.unlink(file.path)
  _stdout, status = Open3.capture2("vips", "resize", path, file.path, factor.to_s)
  return nil unless status.success? && File.file?(file.path)

  file
end

def with_crop(path, vx, vy, vw, vh)
  cropped = crop(path, vx, vy, vw, vh)
  return if cropped.nil?

  yield cropped.path
ensure
  cropped&.close!
end

if mode.nil?
  bigger = upscale(image_path, 2)
  page_path = bigger ? bigger.path : image_path
  image_width, image_height = dimensions(page_path)
  recognize_lines(page_path, psm: 3).each do |line|
    box = vision_box(line[:left], line[:top], line[:width], line[:height], image_width, image_height)
    text = line[:text].gsub("\t", " ")
    printf("%.5f\t%.5f\t%.5f\t%.5f\t%s\n", box[:x], box[:y], box[:w], box[:h], text)
  end
  bigger&.close!
elsif mode == "--epics"
  $stdin.each_line do |line|
    next if line.strip.empty?

    parts = line.chomp.split("\t", -1)
    id = parts[0].to_s
    unless parts.length == 5
      puts "#{id}\t"
      next
    end

    vx, vy, vw, vh = parts[1, 4].map(&:to_f)
    text = ""
    with_crop(image_path, vx, vy, vw, vh) do |cropped|
      bigger = upscale(cropped, 3)
      target = bigger ? bigger.path : cropped
      text = recognize_lines(target, psm: 7, whitelist: true).map { |hit| hit[:text] }.join(" ")
      bigger&.close!
    end
    puts "#{id}\t#{text}"
  end
elsif mode == "--serials"
  $stdin.each_line do |line|
    next if line.strip.empty?

    parts = line.chomp.split("\t", -1)
    id = parts[0].to_s
    unless parts.length == 5
      puts "#{id}\t"
      next
    end

    vx, vy, vw, vh = parts[1, 4].map(&:to_f)
    serial = nil
    with_crop(image_path, vx, vy, vw, vh) do |cropped|
      serial = pure_serial(recognize_lines(cropped, psm: 7))
      if serial.nil?
        bigger = upscale(cropped, 3)
        if bigger
          serial = pure_serial(recognize_lines(bigger.path, psm: 7))
          bigger.close!
        end
      end
    end
    puts "#{id}\t#{serial}"
  end
elsif mode == "--lines"
  $stdin.each_line do |line|
    next if line.strip.empty?

    parts = line.chomp.split("\t", -1)
    next unless parts.length == 5

    id = parts[0]
    vx, vy, vw, vh = parts[1, 4].map(&:to_f)
    with_crop(image_path, vx, vy, vw, vh) do |cropped|
      bigger = upscale(cropped, 2)
      next if bigger.nil?

      hits = recognize_lines(bigger.path, psm: 6)
      bigger.close!
      if hits.empty?
        puts "#{id}\t"
        next
      end

      image_width, image_height = dimensions(bigger.path)
      hits
        .map { |hit| hit.merge(vision_box(hit[:left], hit[:top], hit[:width], hit[:height], image_width, image_height)) }
        .sort_by { |hit| -hit[:y] }
        .each do |hit|
          puts "#{id}\t#{hit[:text].gsub("\t", " ")}"
        end
    end
  end
else
  abort "usage: ocr_page <image> [--serials|--lines|--epics]"
end
