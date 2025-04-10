require "test_helper"

class OmnivoyFlowTest < ActionDispatch::IntegrationTest
  test "can see the home page" do
    get "/"
    assert_dom "h1", "Register with Canvas"
  end
end
