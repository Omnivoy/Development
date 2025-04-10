require "application_system_test_case"

class HomepagesTest < ApplicationSystemTestCase
  test "viewing the homepage" do
    visit root_path
    assert_selector "h1", text: "Register with Canvas"
  end
end
