# test/integration/home_page_integration_test.rb
require "test_helper"

class HomePageIntegrationTest < ActionDispatch::IntegrationTest
  test "home page loads successfully" do
    get root_url
    assert_response :success
    assert_select "h1", "Welcome"
  end
end
