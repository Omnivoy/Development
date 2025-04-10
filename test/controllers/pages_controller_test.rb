require "test_helper"

class PagesControllerTest < ActionDispatch::IntegrationTest
  test "should get help" do
    get help_url
    assert_response :success
    assert_select "h1", "Help"
  end
  test "should get about" do
    get about_url
    assert_response :success
    assert_select "h1", "About"
  end
end