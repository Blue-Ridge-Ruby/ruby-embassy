require "test_helper"

class PlanControllerTest < ActionDispatch::IntegrationTest
  test "index hides passed items from the user's plan by default" do
    alice = users(:attendee_one)
    upcoming = ScheduleItem.create!(day: "fri", title: "Alice-upcoming", kind: :activity,
                                    is_public: true, time_label: "10:00 AM", sort_time: 1000)
    finished = ScheduleItem.create!(day: "fri", title: "Alice-done", kind: :activity,
                                    is_public: true, time_label: "11:00 AM", sort_time: 1100, passed: true)
    alice.plan_items.create!(schedule_item: upcoming)
    alice.plan_items.create!(schedule_item: finished)

    sign_in_as alice
    get plan_path
    assert_match upcoming.title, response.body
    assert_no_match finished.title, response.body
  end

  test "index hides a day section when all the user's plan items on that day are passed" do
    alice = users(:attendee_one)
    fri_done = ScheduleItem.create!(day: "fri", title: "Fri-only-passed", kind: :activity,
                                    is_public: true, time_label: "11:00 AM", sort_time: 1100, passed: true)
    sat_upcoming = ScheduleItem.create!(day: "sat", title: "Sat-still-here", kind: :activity,
                                        is_public: true, time_label: "10:00 AM", sort_time: 1000)
    alice.plan_items.create!(schedule_item: fri_done)
    alice.plan_items.create!(schedule_item: sat_upcoming)

    sign_in_as alice
    get plan_path
    assert_no_match "Friday", response.body
    assert_match "Saturday", response.body

    get plan_path, params: { show_past: "1" }
    assert_match "Friday", response.body
    assert_match "Saturday", response.body
  end

  test "index shows passed items when show_past=1" do
    alice = users(:attendee_one)
    finished = ScheduleItem.create!(day: "fri", title: "Alice-done-visible", kind: :activity,
                                    is_public: true, time_label: "11:00 AM", sort_time: 1100, passed: true)
    alice.plan_items.create!(schedule_item: finished)

    sign_in_as alice
    get plan_path, params: { show_past: "1" }
    assert_match finished.title, response.body
  end
end
