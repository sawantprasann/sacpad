require "test_helper"

class BannerPhotos::PrepareTest < ActiveSupport::TestCase
  test "a png round trip keeps the pixels" do
    pixels = "\x10\x20\x30\xFF\xAA\xBB\xCC\x80".b
    decoded = BannerPhotos::Png.decode(BannerPhotos::Png.encode(pixels, 2, 1))

    assert_equal [ pixels, 2, 1 ], decoded
  end

  test "a checkerboard backdrop is cleared and the photo is cropped to the subject" do
    width = 32
    height = 32
    pixels = String.new(encoding: Encoding::BINARY)
    height.times do |y|
      width.times do |x|
        checker = ((x / 8) + (y / 8)).even? ? 255 : 224
        red = green = blue = checker
        red, green, blue = [ 24, 48, 140 ] if x.between?(10, 21) && y.between?(6, 26)
        pixels << [ red, green, blue, 255 ].pack("C4")
      end
    end

    cleaned = BannerPhotos::Prepare.clean(BannerPhotos::Png.encode(pixels, width, height))
    rgba, crop_width, crop_height = BannerPhotos::Png.decode(cleaned)

    assert_equal 12, crop_width
    assert_equal 21, crop_height
    assert_equal [ 24, 48, 140, 255 ], rgba.byteslice(0, 4).unpack("C4")
    assert_operator BannerPhotos::Png.transparent_ratio(rgba), :<, 0.01
  end

  test "a cutout with a clear margin is cropped to the subject" do
    width = 20
    height = 20
    pixels = ("\x00\x00\x00\x00".b) * (width * height)
    4.times do |y|
      4.times do |x|
        offset = ((8 + y) * width + 8 + x) * 4
        pixels[offset, 4] = "\xC0\x40\x40\xFF".b
      end
    end

    cleaned = BannerPhotos::Prepare.clean(BannerPhotos::Png.encode(pixels, width, height))
    _rgba, crop_width, crop_height = BannerPhotos::Png.decode(cleaned)

    assert_equal 4, crop_width
    assert_equal 4, crop_height
  end

  test "a photo that already fills the frame is left as it was" do
    pixels = "\x20\x40\x80\xFF".b * 16

    assert_nil BannerPhotos::Prepare.clean(BannerPhotos::Png.encode(pixels, 4, 4))
  end

  test "the tiny fixture png does not raise" do
    assert_nil BannerPhotos::Prepare.clean(file_fixture("photo.png").binread)
  end
end
