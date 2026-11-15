module BannerPhotos
  # A PNG often still contains the backdrop from the editor: a white field, or the gray
  # checkerboard used to preview transparency. Those pixels are part of the file, so the
  # banner draws them. This removes that backdrop and crops to the photo.
  class Prepare
    def self.ensure!(organization)
      new(organization).ensure!
    end

    def initialize(organization)
      @organization = organization
    end

    def ensure!
      photo = @organization.banner_photo
      return unless photo.attached?
      return unless photo.blob.content_type == "image/png"
      return if prepared?(photo.blob)

      @organization.with_lock do
        photo = @organization.banner_photo
        return unless photo.attached?
        return if prepared?(photo.blob)

        mark_prepared(photo.blob)
        cleaned = self.class.clean(photo.download)
        next if cleaned.nil?

        @organization.banner_photo.attach(
          io: StringIO.new(cleaned),
          filename: "banner.png",
          content_type: "image/png",
          metadata: { "prepared" => true }
        )
      end
    rescue StandardError => e
      Rails.logger.warn("[banner] could not clear png backdrop: #{e.class}: #{e.message}")
    end

    def self.clean(binary)
      image = Png.decode(binary)
      return nil unless image

      rgba, width, height = image
      return nil if width < 2 || height < 2

      changed = false
      if Png.transparent_ratio(rgba) <= 0.01 && Png.backdrop_border?(rgba, width, height)
        changed = Png.clear_backdrop!(rgba, width, height)
      end
      cropped = Png.crop_to_subject(rgba, width, height)
      return nil unless cropped

      pixels, crop_width, crop_height, did_crop = cropped
      return nil unless changed || did_crop

      Png.encode(pixels, crop_width, crop_height)
    end

    def prepared?(blob)
      blob.metadata["prepared"].in?([ true, "true" ])
    end

    def mark_prepared(blob)
      blob.update!(metadata: blob.metadata.merge("prepared" => true))
    end
  end

  # 8-bit PNG, no interlacing. Enough for photos exported from an editor.
  module Png
    SIGNATURE = "\x89PNG\r\n\x1A\n".b
    module_function

    def decode(bytes)
      bytes = bytes.to_s.b
      return nil unless bytes.start_with?(SIGNATURE)

      width = height = color_type = interlace = nil
      idat = String.new(encoding: Encoding::BINARY)
      pos = 8
      while pos + 12 <= bytes.bytesize
        length = bytes.byteslice(pos, 4).unpack1("N")
        type = bytes.byteslice(pos + 4, 4)
        data = bytes.byteslice(pos + 8, length).to_s
        pos += 12 + length
        case type
        when "IHDR"
          width, height, bit_depth, color_type, _compression, _filter, interlace = data.unpack("NNC5")
          return nil unless bit_depth == 8
        when "IDAT"
          idat << data
        when "IEND"
          break
        end
      end
      return nil if width.to_i < 1 || height.to_i < 1 || interlace != 0

      bpp = { 0 => 1, 2 => 3, 4 => 2, 6 => 4 }[color_type]
      return nil unless bpp

      raw = Zlib.inflate(idat)
      rows = unfilter(raw, width, height, bpp)
      return nil unless rows

      [ to_rgba(rows, width, height, color_type), width, height ]
    rescue Zlib::Error
      nil
    end

    def encode(rgba, width, height)
      raw = String.new(encoding: Encoding::BINARY)
      stride = width * 4
      height.times do |y|
        raw << "\x00"
        raw << rgba.byteslice(y * stride, stride)
      end
      ihdr = [ width, height, 8, 6, 0, 0, 0 ].pack("NNC5")
      signature = SIGNATURE.dup
      signature << chunk("IHDR", ihdr)
      signature << chunk("IDAT", Zlib::Deflate.deflate(raw))
      signature << chunk("IEND", "")
      signature
    end

    def transparent_ratio(rgba)
      pixels = rgba.bytesize / 4
      return 0.0 if pixels.zero?

      clear = 0
      pixels.times { |index| clear += 1 if rgba.getbyte(index * 4 + 3) < 250 }
      clear.to_f / pixels
    end

    def backdrop_border?(rgba, width, height)
      total = 0
      hits = 0
      height.times do |y|
        width.times do |x|
          next unless x.zero? || y.zero? || x == width - 1 || y == height - 1

          total += 1
          hits += 1 if backdrop?(rgba, (y * width + x) * 4)
        end
      end
      total.positive? && (hits.to_f / total) >= 0.75
    end

    def clear_backdrop!(rgba, width, height)
      count = width * height
      seen = "\x00".b * count
      queue = []
      count.times do |index|
        x = index % width
        y = index / width
        next unless x.zero? || y.zero? || x == width - 1 || y == height - 1
        next unless backdrop?(rgba, index * 4)

        seen.setbyte(index, 1)
        queue << index
      end
      return false if queue.empty?

      until queue.empty?
        index = queue.pop
        x = index % width
        y = index / width
        [ [ x - 1, y ], [ x + 1, y ], [ x, y - 1 ], [ x, y + 1 ] ].each do |next_x, next_y|
          next if next_x.negative? || next_y.negative? || next_x >= width || next_y >= height

          next_index = next_y * width + next_x
          next if seen.getbyte(next_index) == 1
          next unless backdrop?(rgba, next_index * 4)

          seen.setbyte(next_index, 1)
          queue << next_index
        end
      end

      cleared = false
      count.times do |index|
        next unless seen.getbyte(index) == 1

        rgba.setbyte(index * 4 + 3, 0)
        cleared = true
      end
      cleared
    end

    def crop_to_subject(rgba, width, height)
      min_x = width
      min_y = height
      max_x = -1
      max_y = -1
      height.times do |y|
        width.times do |x|
          next if rgba.getbyte((y * width + x) * 4 + 3) <= 16

          min_x = x if x < min_x
          min_y = y if y < min_y
          max_x = x if x > max_x
          max_y = y if y > max_y
        end
      end
      return nil if max_x.negative?

      crop_width = max_x - min_x + 1
      crop_height = max_y - min_y + 1
      return [ rgba, width, height, false ] if crop_width == width && crop_height == height

      cropped = String.new(encoding: Encoding::BINARY)
      crop_height.times do |y|
        start = ((min_y + y) * width + min_x) * 4
        cropped << rgba.byteslice(start, crop_width * 4)
      end
      [ cropped, crop_width, crop_height, true ]
    end

    def backdrop?(rgba, offset)
      red = rgba.getbyte(offset)
      green = rgba.getbyte(offset + 1)
      blue = rgba.getbyte(offset + 2)
      alpha = rgba.getbyte(offset + 3)
      return true if alpha < 16
      return false if alpha < 240

      peak = [ red, green, blue ].max
      floor = [ red, green, blue ].min
      peak >= 188 && (peak - floor) <= 28
    end

    def unfilter(raw, width, height, bpp)
      stride = width * bpp
      expected = height * (stride + 1)
      return nil unless raw.bytesize == expected

      rows = String.new(encoding: Encoding::BINARY)
      previous = "\x00".b * stride
      offset = 0
      height.times do
        filter = raw.getbyte(offset)
        offset += 1
        row = raw.byteslice(offset, stride)
        offset += stride
        current = reconstruct(filter, row, previous, bpp)
        return nil unless current

        rows << current
        previous = current
      end
      rows
    end

    def reconstruct(filter, row, previous, bpp)
      return nil unless (0..4).cover?(filter)

      out = Array.new(row.bytesize)
      row.bytesize.times do |index|
        left = index >= bpp ? out[index - bpp] : 0
        up = previous.getbyte(index)
        up_left = index >= bpp ? previous.getbyte(index - bpp) : 0
        value = row.getbyte(index)
        out[index] = case filter
        when 0 then value
        when 1 then (value + left) & 255
        when 2 then (value + up) & 255
        when 3 then (value + ((left + up) / 2)) & 255
        else (value + paeth(left, up, up_left)) & 255
        end
      end
      out.pack("C*")
    end

    def paeth(left, up, up_left)
      estimate = left + up - up_left
      left_distance = (estimate - left).abs
      up_distance = (estimate - up).abs
      up_left_distance = (estimate - up_left).abs
      if left_distance <= up_distance && left_distance <= up_left_distance
        left
      elsif up_distance <= up_left_distance
        up
      else
        up_left
      end
    end

    def to_rgba(rows, width, height, color_type)
      rgba = String.new(encoding: Encoding::BINARY)
      bpp = { 0 => 1, 2 => 3, 4 => 2, 6 => 4 }[color_type]
      height.times do |y|
        width.times do |x|
          offset = (y * width + x) * bpp
          case color_type
          when 6
            rgba << rows.byteslice(offset, 4)
          when 2
            rgba << rows.byteslice(offset, 3) << "\xFF".b
          when 0
            value = rows.byteslice(offset, 1)
            rgba << value << value << value << "\xFF".b
          else
            value = rows.byteslice(offset, 1)
            alpha = rows.byteslice(offset + 1, 1)
            rgba << value << value << value << alpha
          end
        end
      end
      rgba
    end

    def chunk(type, data)
      [ data.bytesize ].pack("N") + type + data + [ Zlib.crc32(type + data) ].pack("N")
    end
  end
end
