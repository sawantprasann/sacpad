require "test_helper"

# Story 1.1 — ticket categories are a global, Admin-managed catalog (like Role/Party), not tenant data.
class TicketCategoryTest < ActiveSupport::TestCase
  test "ticket categories are global reference data, not tenant-scoped" do
    assert_not TicketCategory.ancestors.include?(OrganizationScoped)
  end

  test "name and display_order are required" do
    cat = TicketCategory.new(slug: "x")
    assert_not cat.valid?
    assert cat.errors[:name].any?
    assert cat.errors[:display_order].any?
  end

  test "slug is derived from name when blank" do
    cat = TicketCategory.create!(name: "Road & Transport", display_order: 1)
    assert_equal "road-transport", cat.slug
  end

  test "slug must be unique" do
    TicketCategory.create!(name: "Water", slug: "water", display_order: 1)
    dup = TicketCategory.new(name: "Water II", slug: "water", display_order: 2)
    assert_not dup.valid?
    assert dup.errors[:slug].any?
  end

  test "active scope returns only active rows ordered by display_order" do
    second = TicketCategory.create!(name: "B", slug: "b", display_order: 2, active: true)
    first  = TicketCategory.create!(name: "A", slug: "a", display_order: 1, active: true)
    TicketCategory.create!(name: "Hidden", slug: "hidden", display_order: 3, active: false)

    assert_equal [ first, second ], TicketCategory.active.to_a
  end

  test "seed_defaults! creates the 12 categories idempotently with Other last" do
    assert_difference -> { TicketCategory.count }, 12 do
      TicketCategory.seed_defaults!
    end
    assert_no_difference -> { TicketCategory.count } do
      TicketCategory.seed_defaults!
    end

    other = TicketCategory.find_by(slug: "other")
    assert other, "Other category should be seeded"
    assert_equal 12, other.display_order
    assert_equal TicketCategory.maximum(:display_order), other.display_order
    assert TicketCategory.all.all?(&:active?)
  end
end
