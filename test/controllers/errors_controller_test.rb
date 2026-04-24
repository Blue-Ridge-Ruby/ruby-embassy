require "test_helper"

# Tests for the branded error pages. In production, Rails routes
# exceptions through config.exceptions_app = self.routes, which renders
# the branded view through the app layout. In test env,
# consider_all_requests_local=true normally shows the dev debug page —
# we turn that off here so we exercise the real production error flow.
class ErrorsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @original_show_detailed = Rails.application.env_config["action_dispatch.show_detailed_exceptions"]
    Rails.application.env_config["action_dispatch.show_detailed_exceptions"] = false
  end

  teardown do
    Rails.application.env_config["action_dispatch.show_detailed_exceptions"] = @original_show_detailed
  end

  test "non-admin hitting an admin URL sees the branded 404" do
    sign_in_as users(:attendee_one)
    get admin_users_path
    assert_response :not_found
    assert_select "h1", text: /Page not found/
    assert_select "a[href=?]", "https://blueridgeruby.com", text: /Back to main site/
    assert_select "a[href=?]", dashboard_path, text: /Back to dashboard/
  end

  test "anonymous visitor hitting an admin URL also sees the branded 404" do
    get admin_users_path
    assert_response :not_found
    assert_match "Page not found", response.body
  end
end
