require "test_helper"

class AssignmentTest < ActiveSupport::TestCase
  test "assignments table has expected columns" do
    columns = ActiveRecord::Base.connection.columns(:assignments).map(&:name)

    assert_includes columns, "id"
    assert_includes columns, "title"
    assert_includes columns, "course"
    assert_includes columns, "due_date"
    assert_includes columns, "created_at"
    assert_includes columns, "updated_at"
    puts "Test Success, assignments table has expected columns"
  end
end
