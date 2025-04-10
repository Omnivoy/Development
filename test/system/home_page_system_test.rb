# test/system/home_page_system_test.rb
require "application_system_test_case"

class HomePageSystemTest < ApplicationSystemTestCase
  test "visiting the home page" do
    visit root_url
    assert_selector "h1", text: "Welcome"
  end
end
