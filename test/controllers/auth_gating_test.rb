require "test_helper"

class AuthGatingTest < ActionDispatch::IntegrationTest
  test "anonymous GET /schedule redirects to sign-in" do
    get schedule_path
    assert_redirected_to new_session_path
  end

  test "anonymous GET /plan redirects to sign-in" do
    get plan_path
    assert_redirected_to new_session_path
  end

  test "anonymous GET /dashboard redirects to sign-in" do
    get dashboard_path
    assert_redirected_to new_session_path
  end

  test "anonymous GET / redirects to sign-in" do
    get root_path
    assert_redirected_to new_session_path
  end

  test "anonymous GET /admin/users returns 404" do
    get admin_users_path
    assert_response :not_found
  end

  test "attendee GET /admin/users returns 404" do
    sign_in_as users(:attendee_one)
    get admin_users_path
    assert_response :not_found
  end

  test "volunteer GET /admin/users returns 404" do
    sign_in_as users(:volunteer_one)
    get admin_users_path
    assert_response :not_found
  end

  test "admin GET /admin/users returns 200" do
    sign_in_as users(:jeremy)
    get admin_users_path
    assert_response :success
  end

  test "signed-in attendee GET / redirects to /schedule" do
    sign_in_as users(:attendee_one)
    get root_path
    assert_redirected_to schedule_path
  end

  test "signed-in attendee can view /schedule" do
    sign_in_as users(:attendee_one)
    get schedule_path
    assert_response :success
  end

  test "sign-in page is reachable without authentication" do
    get new_session_path
    assert_response :success
  end

  test "anonymous GET /admin/jobs returns 404" do
    get "/admin/jobs"
    assert_response :not_found
  end

  test "attendee GET /admin/jobs returns 404" do
    sign_in_as users(:attendee_one)
    get "/admin/jobs"
    assert_response :not_found
  end

  test "admin GET /admin/jobs is reachable (200 or redirect)" do
    sign_in_as users(:jeremy)
    get "/admin/jobs"
    assert_includes [ 200, 302 ], response.status
  end
end
