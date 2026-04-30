require "test_helper"

class ScheduleControllerTest < ActionDispatch::IntegrationTest
  test "index hides passed items by default" do
    upcoming = ScheduleItem.create!(day: "fri", title: "Public-upcoming", kind: :activity,
                                    is_public: true, time_label: "10:00 AM", sort_time: 1000)
    finished = ScheduleItem.create!(day: "fri", title: "Public-done", kind: :activity,
                                    is_public: true, time_label: "11:00 AM", sort_time: 1100, passed: true)

    sign_in_as users(:attendee_one)
    get schedule_path
    assert_match upcoming.title, response.body
    assert_no_match finished.title, response.body
  end

  test "index shows passed items when show_past=1" do
    finished = ScheduleItem.create!(day: "fri", title: "Public-done-visible", kind: :activity,
                                    is_public: true, time_label: "11:00 AM", sort_time: 1100, passed: true)

    sign_in_as users(:attendee_one)
    get schedule_path, params: { show_past: "1" }
    assert_match finished.title, response.body
  end
end
