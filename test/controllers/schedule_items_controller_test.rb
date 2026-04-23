require "test_helper"

class ScheduleItemsControllerTest < ActionDispatch::IntegrationTest
  def valid_form_params(overrides = {})
    {
      schedule_item: {
        day: "sat",
        time_label: "6:00 PM",
        sort_time: 1800,
        title: "Dinner with crew",
        location: "Tupelo Honey",
        description: "Bring appetite",
        flexible: false,
        is_public: false
      }.merge(overrides)
    }
  end

  test "anonymous GET /schedule_items/new redirects to sign-in" do
    get new_schedule_item_path
    assert_redirected_to new_session_path
  end

  test "attendee can create a private item" do
    sign_in_as users(:attendee_one)
    assert_difference -> { ScheduleItem.count }, 1 do
      post schedule_items_path, params: valid_form_params
    end
    item = ScheduleItem.last
    assert_equal "activity", item.kind
    assert_equal false, item.is_public
    assert_equal users(:attendee_one), item.created_by
  end

  test "creating a private item auto-plans it for creator" do
    sign_in_as users(:attendee_one)
    assert_difference -> { PlanItem.count }, 1 do
      post schedule_items_path, params: valid_form_params(is_public: false)
    end
  end

  test "creating a public item also auto-plans for creator" do
    sign_in_as users(:attendee_one)
    assert_difference -> { PlanItem.count }, 1 do
      post schedule_items_path, params: valid_form_params(is_public: true)
    end
  end

  test "Turbo Stream create appends item to day container and resets the form frame" do
    sign_in_as users(:attendee_one)
    post schedule_items_path,
         params: valid_form_params(day: "sat", title: "Turbo Dinner", is_public: false),
         headers: { "Accept" => "text/vnd.turbo-stream.html" }
    assert_response :success
    assert_match %r{<turbo-stream action="replace" target="plan_items_sat">}, response.body
    assert_match %r{<turbo-stream action="replace" target="new_schedule_item_sat">}, response.body
    assert_match "Turbo Dinner", response.body
  end

  test "attendee cannot set kind to talk via form tampering" do
    sign_in_as users(:attendee_one)
    post schedule_items_path, params: valid_form_params(kind: "talk")
    assert_equal "activity", ScheduleItem.last.kind
  end

  test "attendee cannot set kind to embassy or lightning" do
    sign_in_as users(:attendee_one)

    post schedule_items_path, params: valid_form_params(kind: "embassy", title: "Sneaky")
    assert_equal "activity", ScheduleItem.find_by(title: "Sneaky").kind

    post schedule_items_path, params: valid_form_params(kind: "lightning", title: "Sneakier")
    assert_equal "activity", ScheduleItem.find_by(title: "Sneakier").kind
  end

  test "attendee can update their own item but kind stays activity" do
    sign_in_as users(:attendee_one)
    item = users(:attendee_one).created_schedule_items.create!(
      day: "thu", title: "Mine", kind: :activity, is_public: true
    )

    patch schedule_item_path(item), params: valid_form_params(title: "Updated", kind: "talk")
    item.reload
    assert_equal "Updated", item.title
    assert_equal "activity", item.kind
  end

  test "attendee gets 404 editing another user's item" do
    other_item = users(:volunteer_one).created_schedule_items.create!(
      day: "thu", title: "Not yours", kind: :activity, is_public: true
    )

    sign_in_as users(:attendee_one)
    get edit_schedule_item_path(other_item)
    assert_response :not_found

    patch schedule_item_path(other_item), params: valid_form_params(title: "Hack")
    assert_response :not_found
    assert_equal "Not yours", other_item.reload.title
  end

  test "DELETE route does not exist" do
    sign_in_as users(:attendee_one)
    item = users(:attendee_one).created_schedule_items.create!(
      day: "thu", title: "Mine", kind: :activity, is_public: true
    )

    delete "/schedule_items/#{item.id}"
    # Route isn't defined; Rails returns 404 Not Found (no DELETE route matches).
    assert_equal 404, response.status
    assert ScheduleItem.exists?(item.id), "item should not be destroyed"
  end

  test "created_by is forced to current_user, ignoring any param" do
    sign_in_as users(:attendee_one)
    post schedule_items_path, params: valid_form_params(
      title: "Impersonation attempt",
      created_by_id: users(:volunteer_one).id
    )
    item = ScheduleItem.find_by(title: "Impersonation attempt")
    assert_equal users(:attendee_one), item.created_by
  end
end
