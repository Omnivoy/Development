Course Model for Omnivoy

# app/models/course.rb

class Course < ApplicationRecord
  # Associations
  belongs_to :user
  has_many :tasks, dependent: :destroy
  
  # Validations
  validates :name, presence: true
  validates :canvas_course_id, presence: true, uniqueness: { scope: :user_id }
  
  # Scopes
  scope :active, -> { where(active: true) }
  scope :inactive, -> { where(active: false) }
  scope :current_term, -> { where(current_term: true) }
  
  # Calculate the current grade for this course based on completed assignments
  def calculate_current_grade
    completed_tasks = tasks.completed
    
    return nil if completed_tasks.empty?
    
    total_points_earned = 0
    total_points_possible = 0
    
    completed_tasks.each do |task|
      next unless task.score.present? && task.weight.present?
      
      total_points_earned += task.score
      total_points_possible += task.weight
    end
    
    return nil if total_points_possible.zero?
    
    # Calculate percentage
    percentage = (total_points_earned / total_points_possible) * 100
    update(current_grade: percentage)
    
    percentage
  end
  
  # Get all upcoming deadlines for this course
  def upcoming_deadlines(days = 7)
    tasks.upcoming.where('due_date <= ?', Date.today + days.days)
  end
  
  # Get count of remaining tasks
  def remaining_tasks_count
    tasks.incomplete.count
  end
  
  # Method to sync course with Canvas
  def self.sync_from_canvas(user, canvas_course)
    course = user.courses.find_or_initialize_by(canvas_course_id: canvas_course.id)
    
    course.update(
      name: canvas_course.name,
      code: canvas_course.course_code,
      start_date: canvas_course.start_at,
      end_date: canvas_course.end_at,
      url: canvas_course.html_url,
      active: canvas_course.workflow_state == 'available',
      current_term: is_current_term?(canvas_course)
    )
    
    course
  end
  
  # Method to sync all assignments for this course from Canvas
  def sync_assignments_from_canvas(canvas_api)
    assignments = canvas_api.get_course_assignments(canvas_course_id)
    
    assignments.each do |canvas_assignment|
      Task.sync_from_canvas(user, canvas_assignment)
    end
  end
  
  private
  
  # Helper method to determine if a course is in the current term
  def self.is_current_term?(canvas_course)
    return false if canvas_course.end_at.nil?
    
    current_date = Date.today
    end_date = canvas_course.end_at.to_date
    
    # Course is current if it hasn't ended yet or ended within the last month
    end_date >= current_date || (current_date - end_date) <= 30.days
  end
end
