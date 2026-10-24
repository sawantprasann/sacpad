class SupportMessage < ApplicationRecord
  include OrganizationScoped

  ALLOWED_IMAGE_TYPES = %w[image/jpeg image/png image/gif image/webp].freeze
  MAX_IMAGES = 5
  MAX_IMAGE_BYTES = 8.megabytes

  belongs_to :support_ticket, inverse_of: :messages, touch: true
  belongs_to :author, polymorphic: true
  has_many_attached :images

  validates :body, presence: true, length: { maximum: 5_000 }, unless: -> { images.attached? }
  validates :author_type, inclusion: { in: %w[User Admin] }
  validate :images_are_photos

  before_validation :normalize_body

  def from_support?
    author_type == "Admin"
  end

  def author_name
    author&.name.presence || (from_support? ? "SAC-PAD support" : "User")
  end

  def author_detail
    from_support? ? "SAC-PAD support" : author&.email
  end

  def self.image_problems(files)
    list = Array(files).reject(&:blank?)
    problems = []
    problems << "are limited to #{MAX_IMAGES} per message" if list.size > MAX_IMAGES

    list.each do |file|
      type = file.try(:content_type) || file.try(:blob)&.content_type
      size = file.try(:byte_size) || file.try(:blob)&.byte_size || file.try(:size)
      unless type.to_s.in?(ALLOWED_IMAGE_TYPES)
        problems << "must be JPEG, PNG, GIF, or WebP"
        break
      end
      if size.to_i > MAX_IMAGE_BYTES
        problems << "must be 8 MB or smaller"
        break
      end
    end
    problems
  end

  private

  def images_are_photos
    self.class.image_problems(images.blobs).each { |problem| errors.add(:images, problem) }
  end

  def normalize_body
    self.body = body.to_s.strip
  end
end
