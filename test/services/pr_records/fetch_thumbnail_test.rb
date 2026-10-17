require "test_helper"

class PrRecords::FetchThumbnailTest < ActiveSupport::TestCase
  test "reads an og:image url and keeps only that url" do
    html = '<html><head><meta property="og:image" content="https://cdn.example/thumb.jpg"></head></html>'
    assert_equal "https://cdn.example/thumb.jpg", PrRecords::FetchThumbnail.parse(html, "https://news.example/story")
  end

  test "turns a relative thumbnail into an absolute url" do
    html = '<meta property="og:image" content="/images/thumb.jpg">'
    assert_equal "https://news.example/images/thumb.jpg", PrRecords::FetchThumbnail.parse(html, "https://news.example/story")
  end

  test "rejects a link that is not http" do
    error = assert_raises(PrRecords::FetchThumbnail::Error) do
      PrRecords::FetchThumbnail.call("javascript:alert(1)")
    end
    assert_match "http", error.message
  end
end
