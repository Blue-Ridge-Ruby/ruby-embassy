require "test_helper"

class Admin::ScheduleItemsControllerTest < ActionDispatch::IntegrationTest
  def valid_form_params(overrides = {})
    {
      schedule_item: {
        day: "fri",
        time_label: "9:00 AM",
        sort_time: 900,
        title: "Admin-created Talk",
        host: "Someone",
        kind: "talk",
        flexible: false,
        is_public: true
      }.merge(overrides)
    }
  end

  test "attendee GET /admin/schedule_items returns 404" do
    sign_in_as users(:attendee_one)
    get admin_schedule_items_path
    assert_response :not_found
  end

  test "volunteer GET /admin/schedule_items returns 404" do
    sign_in_as users(:volunteer_one)
    get admin_schedule_items_path
    assert_response :not_found
  end

  test "admin GET /admin/schedule_items returns 200" do
    sign_in_as users(:jeremy)
    get admin_schedule_items_path
    assert_response :success
  end

  test "admin schedule index shows RSVPs column with kind-aware counts and small action buttons" do
    ScheduleItem.create!(day: "fri", time_label: "9:00 AM", sort_time: 900,
                         title: "Talk fixture", kind: "talk", is_public: true, flexible: false)
    sign_in_as users(:jeremy)
    get admin_schedule_items_path
    assert_response :success

    assert_select "th", text: "RSVPs"
    assert_select "a.btn.btn-muted.btn-small", text: "Edit"
    assert_select "form button.btn.btn-red.btn-small", text: "Delete"
    assert_match "max-w-7xl", @response.body
  end

  test "admin can create an item of kind: talk" do
    sign_in_as users(:jeremy)
    assert_difference -> { ScheduleItem.count }, 1 do
      post admin_schedule_items_path, params: valid_form_params
    end
    assert_equal "talk", ScheduleItem.last.kind
  end

  test "admin can create an item of kind: embassy" do
    sign_in_as users(:jeremy)
    post admin_schedule_items_path, params: valid_form_params(
      kind: "embassy",
      title: "Registration",
      offers_new_passport: "1",
      new_passport_capacity: 8
    )
    assert_equal "embassy", ScheduleItem.find_by(title: "Registration").kind
  end

  test "admin can edit any item's kind" do
    item = ScheduleItem.create!(day: "thu", title: "Original", kind: :activity, is_public: true)
    sign_in_as users(:jeremy)

    patch admin_schedule_item_path(item), params: valid_form_params(kind: "talk", title: "Changed")
    item.reload
    assert_equal "talk", item.kind
    assert_equal "Changed", item.title
  end

  test "admin can delete items (including user-created ones)" do
    user_item = users(:attendee_one).created_schedule_items.create!(
      day: "sat", title: "Attendee's activity", kind: :activity, is_public: true
    )
    sign_in_as users(:jeremy)

    assert_difference -> { ScheduleItem.count }, -1 do
      delete admin_schedule_item_path(user_item)
    end
  end

  test "delete cascades associated plan_items" do
    item = ScheduleItem.create!(day: "thu", title: "Cascade test", kind: :activity, is_public: true)
    users(:attendee_one).plan_items.create!(schedule_item: item)
    users(:volunteer_one).plan_items.create!(schedule_item: item)

    sign_in_as users(:jeremy)
    assert_difference -> { PlanItem.count }, -2 do
      delete admin_schedule_item_path(item)
    end
  end

  test "admin edit form renders host as a select with existing user names" do
    item = ScheduleItem.create!(day: "thu", title: "Test talk", kind: :talk, is_public: true)
    sign_in_as users(:jeremy)
    get edit_admin_schedule_item_path(item)

    assert_select "select[name='schedule_item[host]']" do
      # Every existing user's full_name should be an option.
      User.all.each do |u|
        assert_select "option", text: u.full_name
      end
    end
  end

  test "admin index shows item descriptions when present" do
    ScheduleItem.create!(
      day: "thu",
      title: "Admin desc",
      description: "Short admin-visible description.",
      kind: :activity,
      is_public: true
    )
    sign_in_as users(:jeremy)
    get admin_schedule_items_path
    assert_match "Short admin-visible description.", response.body
  end

  test "admin edit form preserves an external speaker host value as a sticky option" do
    item = ScheduleItem.create!(day: "thu", title: "Keynote", host: "John Athayde", kind: :talk, is_public: true)
    sign_in_as users(:jeremy)
    get edit_admin_schedule_item_path(item)

    assert_select "select[name='schedule_item[host]']" do
      assert_select "option[selected='selected']", text: "John Athayde"
    end
  end

  test "admin edit form exposes a host_url field so name and link stay paired" do
    item = ScheduleItem.create!(
      day: "thu", title: "Keynote", host: "John Athayde",
      host_url: "https://blueridgeruby.com/speakers/john-athayde/",
      kind: :talk, is_public: true
    )
    sign_in_as users(:jeremy)
    get edit_admin_schedule_item_path(item)

    assert_select "input[name='schedule_item[host_url]'][value=?]",
                  "https://blueridgeruby.com/speakers/john-athayde/"
  end

  test "admin update persists host_url alongside host" do
    item = ScheduleItem.create!(
      day: "thu", title: "Keynote", host: "John Athayde",
      host_url: "https://blueridgeruby.com/speakers/john-athayde/",
      kind: :talk, is_public: true
    )
    sign_in_as users(:jeremy)

    patch admin_schedule_item_path(item), params: valid_form_params(
      title: "Keynote", host: "Joël Quenneville",
      host_url: "https://blueridgeruby.com/speakers/joel-quenneville/"
    )

    item.reload
    assert_equal "Joël Quenneville", item.host
    assert_equal "https://blueridgeruby.com/speakers/joel-quenneville/", item.host_url
  end

  test "admin can create a volunteers_only public item" do
    sign_in_as users(:jeremy)
    post admin_schedule_items_path, params: valid_form_params(
      title: "Volunteer briefing", audience: "volunteers_only"
    )
    item = ScheduleItem.find_by(title: "Volunteer briefing")
    assert_equal "volunteers_only", item.audience
  end

  test "admin can update an item's audience" do
    item = ScheduleItem.create!(day: "thu", title: "Update test", kind: :talk, is_public: true)
    assert_equal "everyone", item.audience

    sign_in_as users(:jeremy)
    patch admin_schedule_item_path(item), params: valid_form_params(audience: "volunteers_only")
    assert_equal "volunteers_only", item.reload.audience
  end

  test "admin index remembers kind filter across param-less revisits" do
    ScheduleItem.create!(day: "fri", title: "Filter-talk", kind: :talk, is_public: true)
    ScheduleItem.create!(day: "fri", title: "Filter-meal", kind: :meal, is_public: true)
    sign_in_as users(:jeremy)

    get admin_schedule_items_path, params: { kind: "talk" }
    assert_match "Filter-talk", response.body
    assert_no_match "Filter-meal", response.body

    get admin_schedule_items_path
    assert_match "Filter-talk", response.body
    assert_no_match "Filter-meal", response.body
  end

  test "admin index remembers day filter across param-less revisits" do
    ScheduleItem.create!(day: "fri", title: "Friday-only", kind: :talk, is_public: true)
    ScheduleItem.create!(day: "sat", title: "Saturday-only", kind: :talk, is_public: true)
    sign_in_as users(:jeremy)

    get admin_schedule_items_path, params: { day: "fri" }
    assert_match "Friday-only", response.body
    assert_no_match "Saturday-only", response.body

    get admin_schedule_items_path
    assert_match "Friday-only", response.body
    assert_no_match "Saturday-only", response.body
  end

  test "admin index clears persisted kind filter when 'All' sends empty kind" do
    ScheduleItem.create!(day: "fri", title: "Clear-talk", kind: :talk, is_public: true)
    ScheduleItem.create!(day: "fri", title: "Clear-meal", kind: :meal, is_public: true)
    sign_in_as users(:jeremy)

    get admin_schedule_items_path, params: { kind: "talk" }
    get admin_schedule_items_path, params: { kind: "" }
    assert_match "Clear-talk", response.body
    assert_match "Clear-meal", response.body

    # And it stays cleared on the next param-less revisit.
    get admin_schedule_items_path
    assert_match "Clear-talk", response.body
    assert_match "Clear-meal", response.body
  end

  test "admin index hides passed items by default and shows them with show_past=1" do
    upcoming = ScheduleItem.create!(day: "fri", title: "Still upcoming", kind: :talk, is_public: true)
    finished = ScheduleItem.create!(day: "fri", title: "Already done", kind: :talk, is_public: true, passed: true)
    sign_in_as users(:jeremy)

    get admin_schedule_items_path
    assert_match upcoming.title, response.body
    assert_no_match finished.title, response.body

    get admin_schedule_items_path, params: { show_past: "1" }
    assert_match upcoming.title, response.body
    assert_match finished.title, response.body
  end

  test "admin index remembers show_past across param-less revisits" do
    upcoming = ScheduleItem.create!(day: "fri", title: "Persist-upcoming", kind: :talk, is_public: true)
    finished = ScheduleItem.create!(day: "fri", title: "Persist-done", kind: :talk, is_public: true, passed: true)
    sign_in_as users(:jeremy)

    get admin_schedule_items_path, params: { show_past: "1" }
    assert_match finished.title, response.body

    get admin_schedule_items_path
    assert_match finished.title, response.body
    assert_match upcoming.title, response.body
  end

  test "admin toggle_passed flips the boolean" do
    item = ScheduleItem.create!(day: "thu", title: "Toggle target", kind: :talk, is_public: true)
    assert_equal false, item.passed

    sign_in_as users(:jeremy)
    patch toggle_passed_admin_schedule_item_path(item)
    assert_equal true, item.reload.passed

    patch toggle_passed_admin_schedule_item_path(item)
    assert_equal false, item.reload.passed
  end

  test "non-admin cannot toggle_passed" do
    item = ScheduleItem.create!(day: "thu", title: "Locked", kind: :talk, is_public: true)
    sign_in_as users(:attendee_one)
    patch toggle_passed_admin_schedule_item_path(item)
    assert_response :not_found
    assert_equal false, item.reload.passed
  end

  test "admin filter survives edit→update→redirect" do
    keep   = ScheduleItem.create!(day: "fri", title: "Survives-talk", kind: :talk, is_public: true)
    other  = ScheduleItem.create!(day: "fri", title: "Hidden-meal",  kind: :meal, is_public: true)
    sign_in_as users(:jeremy)

    get admin_schedule_items_path, params: { kind: "talk" }
    patch admin_schedule_item_path(keep), params: valid_form_params(kind: "talk", title: "Survives-talk-renamed")
    follow_redirect!

    assert_match "Survives-talk-renamed", response.body
    assert_no_match other.title, response.body
  end
end
