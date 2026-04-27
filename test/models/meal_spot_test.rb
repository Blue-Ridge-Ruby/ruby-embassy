require "test_helper"

class MealSpotTest < ActiveSupport::TestCase
  def meal
    @meal ||= ScheduleItem.create!(day: "thu", title: "Lunch", kind: :meal, is_public: true)
  end

  def build_spot(name: "Hattie B's", creator: users(:attendee_one))
    meal.meal_spots.create!(name: name, created_by: creator)
  end

  test "rejects spots whose parent isn't a meal" do
    talk = ScheduleItem.create!(day: "thu", title: "Keynote", kind: :talk, is_public: true)
    spot = talk.meal_spots.build(name: "Anywhere", created_by: users(:attendee_one))
    assert_not spot.valid?
    assert_includes spot.errors[:schedule_item], "must be a meal event"
  end

  test "name is unique per meal, case-insensitively" do
    build_spot(name: "Hattie B's")
    dup = meal.meal_spots.build(name: "hattie b's", created_by: users(:volunteer_one))
    assert_not dup.valid?
    assert_includes dup.errors[:name], "has already been taken"
  end

  test "editable_by? lets the creator edit until anyone else RSVPs" do
    spot = build_spot(creator: users(:attendee_one))
    transport = spot.transports.create!(mode: :walking, departs_at: 1.hour.from_now)
    transport.rsvps.create!(user: users(:attendee_one))

    assert spot.editable_by?(users(:attendee_one)),  "creator can edit before others join"
    assert_not spot.editable_by?(users(:volunteer_one)), "non-creator can't edit"

    transport.rsvps.create!(user: users(:volunteer_one))
    spot.reload
    assert_not spot.editable_by?(users(:attendee_one)),  "creator locked out once others join"
    assert spot.editable_by?(users(:jeremy)), "admins can always edit"
  end

  test "ownership transfers when the creator un-RSVPs" do
    spot = build_spot(creator: users(:attendee_one))
    transport = spot.transports.create!(mode: :walking, departs_at: 1.hour.from_now)
    creator_rsvp = transport.rsvps.create!(user: users(:attendee_one))
    transport.rsvps.create!(user: users(:volunteer_one))

    creator_rsvp.destroy!
    assert_equal users(:volunteer_one), spot.reload.created_by
  end

  # ----- Canonical spot for hosted meals ----------------------------------

  test "canonical_for_hosted! creates one spot mirroring the meal's location" do
    hosted = ScheduleItem.create!(day: "thu", title: "Welcome dinner", kind: :meal,
                                   is_public: true, host: "Alice",
                                   location: "Pleasant Garden Inn",
                                   map_url: "https://maps.app.goo.gl/x")

    spot = MealSpot.canonical_for_hosted!(hosted)
    assert_equal "Pleasant Garden Inn", spot.name
    assert_equal "https://maps.app.goo.gl/x", spot.map_url
    assert_nil spot.created_by_id
    assert spot.is_public
  end

  test "canonical_for_hosted! falls back to host when location is blank" do
    hosted = ScheduleItem.create!(day: "thu", title: "Pop-up brunch", kind: :meal,
                                   is_public: true, host: "Alice's place",
                                   host_url: "https://maps.app.goo.gl/y")

    spot = MealSpot.canonical_for_hosted!(hosted)
    assert_equal "Alice's place", spot.name
    assert_equal "https://maps.app.goo.gl/y", spot.map_url
  end

  test "canonical_for_hosted! is idempotent" do
    hosted = ScheduleItem.create!(day: "thu", title: "Welcome dinner", kind: :meal,
                                   is_public: true, host: "Alice",
                                   location: "Pleasant Garden Inn")

    first  = MealSpot.canonical_for_hosted!(hosted)
    second = MealSpot.canonical_for_hosted!(hosted)
    assert_equal first.id, second.id
    assert_equal 1, hosted.meal_spots.count
  end

  test "canonical_for_hosted? returns true only for nil-creator spots on hosted meals" do
    hosted = ScheduleItem.create!(day: "thu", title: "Welcome dinner", kind: :meal,
                                   is_public: true, host: "Alice",
                                   location: "Pleasant Garden Inn")
    canonical = MealSpot.canonical_for_hosted!(hosted)
    user_spot = build_spot

    assert canonical.canonical_for_hosted?
    assert_not user_spot.canonical_for_hosted?, "user-suggested spots are not canonical"
  end

  test "editable_by? on a canonical (nil-creator) spot allows admins only" do
    hosted = ScheduleItem.create!(day: "thu", title: "Welcome dinner", kind: :meal,
                                   is_public: true, host: "Alice",
                                   location: "Pleasant Garden Inn")
    canonical = MealSpot.canonical_for_hosted!(hosted)

    assert     canonical.editable_by?(users(:jeremy)), "admin can edit"
    assert_not canonical.editable_by?(users(:attendee_one)), "regular user cannot edit"
    assert_not canonical.editable_by?(nil), "anonymous cannot edit"
  end

  test "transfer_ownership_if_creator_left! is a no-op for canonical spots" do
    hosted = ScheduleItem.create!(day: "thu", title: "Welcome dinner", kind: :meal,
                                   is_public: true, host: "Alice",
                                   location: "Pleasant Garden Inn")
    canonical = MealSpot.canonical_for_hosted!(hosted)
    transport = canonical.transports.create!(mode: :walking, departs_at: 1.hour.from_now)
    rsvp = transport.rsvps.create!(user: users(:attendee_one))

    rsvp.destroy!
    assert_nil canonical.reload.created_by_id, "canonical spot stays creatorless"
  end
end
