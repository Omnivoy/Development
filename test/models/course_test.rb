require 'test_helper'

class CourseTest < ActiveSupport::TestCase
  setup do
    @user = users(:student)
    @course = courses(:math101)
  end

  test "should be valid with valid attributes" do
    assert @course.valid?
  end

  test "should not be valid without a name" do
    @course.name = nil
    assert_not @course.valid?
    assert_includes @course.errors[:name], "can't be blank"
  end

  test "should not be valid without a canvas_course_id" do
    @course.canvas_course_id = nil
    assert_not @course.valid?
    assert_includes @course.errors[:canvas_course_id], "can't be blank"
  end

  test "should ensure canvas_course_id is unique per user" do
    duplicate_course = @course.dup
    assert_not duplicate_course.valid?
    assert_includes duplicate_course.errors[:canvas_course_id], "has already been taken"
  end

  test "should allow same canvas_course_id for different users" do
    another_user = users(:teacher)
    duplicate_course = @course.dup
    duplicate_course.user = another_user
    assert duplicate_course.valid?
  end

  test "should calculate current grade correctly" do
    # Create tasks with scores
    create_task(@course, 90, 100) # 90%
    create_task(@course, 80, 100) # 80%
    
    assert_equal 85.0, @course.calculate_current_grade
    assert_equal 85.0, @course.current_grade
  end

  test "should return nil for current grade when no completed tasks" do
    @course.tasks.delete_all
    assert_nil @course.calculate_current_grade
  end

  test "should return nil for current grade when completed tasks have no scores" do
    task = create_task(@course, nil, 100)
    task.complete!
    assert_nil @course.calculate_current_grade
  end

  test "should return correct upcoming deadlines" do
    # Create tasks with different due dates
    today_task = create_task(@course, nil, nil, Date.today)
    tomorrow_task = create_task(@course, nil, nil, Date.today + 1.day)
    next_week_task = create_task(@course, nil, nil, Date.today + 8.days)
    
    upcoming_tasks = @course.upcoming_deadlines(7)
    
    assert_includes upcoming_tasks, today_task
    assert_includes upcoming_tasks, tomorrow_task
    assert_not_includes upcoming_tasks, next_week_task
  end

  test "should count remaining tasks correctly" do
    # Create tasks with different completion statuses
    create_task(@course).complete!
    create_task(@course)
    create_task(@course)
    
    assert_equal 2, @course.remaining_tasks_count
  end

  test "should sync from canvas correctly" do
    canvas_course = OpenStruct.new(
      id: "12345",
      name: "Advanced Physics",
      course_code: "PHYS301",
      start_at: Date.today - 1.month,
      end_at: Date.today + 2.months,
      html_url: "https://canvas.example.com/courses/12345",
      workflow_state: "available"
    )
    
    course = Course.sync_from_canvas(@user, canvas_course)
    
    assert_equal "Advanced Physics", course.name
    assert_equal "PHYS301", course.code
    assert_equal "12345", course.canvas_course_id
    assert course.active
    assert course.current_term
  end

  test "should identify current term correctly" do
    # Test current course
    canvas_course = OpenStruct.new(end_at: Date.today + 1.month)
    assert Course.send(:is_current_term?, canvas_course)
    
    # Test recently ended course (within 30 days)
    canvas_course = OpenStruct.new(end_at: Date.today - 15.days)
    assert Course.send(:is_current_term?, canvas_course)
    
    # Test old course (more than 30 days ago)
    canvas_course = OpenStruct.new(end_at: Date.today - 45.days)
    assert_not Course.send(:is_current_term?, canvas_course)
  end

  private
  
  def create_task(course, score = nil, weight = nil, due_date = nil)
    task = Task.create!(
      title: "Test Task #{rand(1000)}",
      due_date: due_date || Date.today + 1.day,
      user: course.user,
      course: course,
      score: score,
      weight: weight,
      completed: score.present?
    )
    task.complete! if score.present?
    task
  end
end
