require "test_helper"

class PrCategoryTest < ActiveSupport::TestCase
  test "creates a pr category with defaults" do
    cat = PrCategory.create!(name: "Electronic Media", slug: "electronic")
    assert_equal "Electronic Media", cat.name
    assert_equal "electronic", cat.slug
    assert cat.active
  end

  test "derives slug from name" do
    cat = PrCategory.new(name: "Electronic Media")
    cat.validate
    assert_equal "electronic-media", cat.slug
  end

  test "seeds the 6 default PR categories" do
    PrCategory.delete_all
    PrCategory.seed_defaults!
    assert_equal 6, PrCategory.count
    assert PrCategory.find_by(slug: "electronic")
    assert PrCategory.find_by(slug: "podcasts")
  end

  test "active scope returns only active categories in order" do
    PrCategory.delete_all
    PrCategory.seed_defaults!
    inactive = PrCategory.find_by(slug: "electronic")
    inactive.update(active: false)
    assert_equal 5, PrCategory.active.count
  end
end
