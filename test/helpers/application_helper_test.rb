require "test_helper"

class ApplicationHelperTest < ActionView::TestCase
  test "linkify turns http and www addresses into new-tab links" do
    html = linkify_text("See https://example.com/story. and www.paper.example/a")

    assert_includes html, 'href="https://example.com/story"'
    assert_includes html, 'target="_blank"'
    assert_includes html, 'rel="noopener noreferrer"'
    assert_not_includes html, 'href="https://example.com/story."'
    assert_includes html, 'href="https://www.paper.example/a"'
    assert_includes html, ">www.paper.example/a<"
  end

  test "linkify keeps parentheses that belong to the url" do
    html = linkify_text("https://en.wikipedia.org/wiki/Ruby_(programming_language)")

    assert_includes html, 'href="https://en.wikipedia.org/wiki/Ruby_(programming_language)"'
  end

  test "linkify escapes the rest of the note and ignores javascript urls" do
    html = linkify_text("<script>alert(1)</script> javascript:alert(1)")

    assert_not_includes html, "<script>"
    assert_includes html, "&lt;script&gt;"
    assert_not_includes html, 'href="javascript:'
  end

  test "format_nidhi drops an empty fraction and keeps a real one" do
    assert_equal "250,000", format_nidhi(250000)
    assert_equal "250,000.5", format_nidhi(BigDecimal("250000.50"))
    assert_equal "0", format_nidhi(nil)
  end

  test "format_estimated_cost leaves a blank cost empty" do
    assert_equal "—", format_estimated_cost(nil)
    assert_equal "1,500.5", format_estimated_cost(BigDecimal("1500.50"))
  end
end
