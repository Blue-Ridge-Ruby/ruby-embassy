require "test_helper"

class ReportControllerTest < ActionDispatch::IntegrationTest
  test "should get index" do
    get report_url
    assert_response :success
  end
end
