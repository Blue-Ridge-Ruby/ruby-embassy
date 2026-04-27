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

  test "admin can create an item of kind: talk" do
    sign_in_as users(:jeremy)
    assert_difference -> { ScheduleItem.count }, 1 do
      post admin_schedule_items_path, params: valid_form_params
    end
    assert_equal "talk", ScheduleItem.last.kind
  end

  test "admin can create an item of kind: embassy" do
    sign_in_as users(:jeremy)
    post admin_schedule_items_path, params: valid_form_params(kind: "embassy", title: "Registration")
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
end
