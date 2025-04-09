require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "users table has expected columns" do
    columns = ActiveRecord::Base.connection.columns(:users).map(&:name)

    assert_includes columns, "id"
    assert_includes columns, "username"
    assert_includes columns, "password"
    assert_includes columns, "email"
    assert_includes columns, "created_at"
    assert_includes columns, "updated_at"
    puts "Test Success, users table has expected columns"
  end
end