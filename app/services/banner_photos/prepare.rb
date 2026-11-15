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
end
