require "test_helper"

class FaqsTest < ActionDispatch::IntegrationTest
  test "faqs page loads" do
    get "/faqs"
    assert_response :success
    assert_select "h1", "FAQ"
  end
end
