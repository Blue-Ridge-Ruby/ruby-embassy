require "test_helper"

class ScheduleItemTest < ActiveSupport::TestCase
  def valid_attrs(overrides = {})
    {
      day: "thu",
      title: "Test Item",
      kind: :activity,
      is_public: true
    }.merge(overrides)
  end

  test "requires title" do
    item = ScheduleItem.new(valid_attrs(title: nil))
    assert_not item.valid?
    assert_includes item.errors[:title], "can't be blank"
  end

  test "requires day" do
    item = ScheduleItem.new(valid_attrs(day: nil))
    assert_not item.valid?
    assert_includes item.errors[:day], "can't be blank"
  end

  test "requires kind" do
    item = ScheduleItem.new(valid_attrs.except(:kind))
    assert_not item.valid?
    assert_includes item.errors[:kind], "can't be blank"
  end

  test "kind enum exposes talk/lightning/embassy/activity" do
    assert_equal %w[talk lightning embassy activity], ScheduleItem.kinds.keys
    assert_equal 0, ScheduleItem.kinds["talk"]
    assert_equal 1, ScheduleItem.kinds["lightning"]
    assert_equal 2, ScheduleItem.kinds["embassy"]
    assert_equal 3, ScheduleItem.kinds["activity"]
  end

  test "is_public defaults to false" do
    item = ScheduleItem.new(valid_attrs.except(:is_public))
    assert_equal false, item.is_public
  end

  test "flexible defaults to false" do
    item = ScheduleItem.new(valid_attrs)
    assert_equal false, item.flexible
  end

  test "talk? returns true only for talk kind" do
    assert ScheduleItem.new(valid_attrs(kind: :talk)).talk?
    assert_not ScheduleItem.new(valid_attrs(kind: :activity)).talk?
    assert_not ScheduleItem.new(valid_attrs(kind: :lightning)).talk?
    assert_not ScheduleItem.new(valid_attrs(kind: :embassy)).talk?
  end

  test "rsvp_count counts plan_items" do
    item = ScheduleItem.create!(valid_attrs)
    assert_equal 0, item.rsvp_count
    item.plan_items.create!(user: users(:attendee_one))
    item.plan_items.create!(user: users(:volunteer_one))
    assert_equal 2, item.reload.rsvp_count
  end

  test "editable_by? admin can edit any item" do
    item = ScheduleItem.create!(valid_attrs(created_by: users(:attendee_one)))
    assert item.editable_by?(users(:jeremy))
  end

  test "editable_by? creator can edit own item" do
    item = ScheduleItem.create!(valid_attrs(created_by: users(:attendee_one)))
    assert item.editable_by?(users(:attendee_one))
  end

  test "editable_by? non-creator non-admin cannot edit" do
    item = ScheduleItem.create!(valid_attrs(created_by: users(:attendee_one)))
    assert_not item.editable_by?(users(:volunteer_one))
  end

  test "public_items scope returns only items with is_public: true" do
    public_item = ScheduleItem.create!(valid_attrs(title: "Public", is_public: true))
    private_item = ScheduleItem.create!(valid_attrs(title: "Private", is_public: false))
    assert_includes ScheduleItem.public_items, public_item
    assert_not_includes ScheduleItem.public_items, private_item
  end

  test "ordered scope orders by day then sort_time" do
    wed_am = ScheduleItem.create!(valid_attrs(day: "wed", sort_time: 900, title: "Wed AM"))
    wed_pm = ScheduleItem.create!(valid_attrs(day: "wed", sort_time: 1800, title: "Wed PM"))
    thu_am = ScheduleItem.create!(valid_attrs(day: "thu", sort_time: 900, title: "Thu AM"))
    ordered = ScheduleItem.where(id: [ wed_am.id, wed_pm.id, thu_am.id ]).ordered
    assert_equal [ wed_am, wed_pm, thu_am ], ordered.to_a
  end

  test "after_create auto-plans private items for creator" do
    assert_difference -> { PlanItem.count }, 1 do
      ScheduleItem.create!(valid_attrs(
        title: "Private Dinner",
        is_public: false,
        created_by: users(:attendee_one)
      ))
    end
    assert_equal users(:attendee_one), PlanItem.last.user
  end

  test "after_create auto-plans public items for creator too" do
    assert_difference -> { PlanItem.count }, 1 do
      ScheduleItem.create!(valid_attrs(
        title: "Public Activity",
        is_public: true,
        created_by: users(:attendee_one)
      ))
    end
    assert_equal users(:attendee_one), PlanItem.last.user
  end

  test "after_create does not auto-plan seeded items (no creator)" do
    assert_no_difference -> { PlanItem.count } do
      ScheduleItem.create!(valid_attrs(
        title: "Seeded-Like",
        is_public: true,
        created_by: nil
      ))
    end
  end
end
