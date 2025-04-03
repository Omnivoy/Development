require 'rails_helper'

RSpec.describe Course, type: :model do
  let(:user) { create(:user) }
  let(:course) { create(:course, user: user) }
  
  describe 'associations' do
    it { should belong_to(:user) }
    it { should have_many(:tasks).dependent(:destroy) }
  end
  
  describe 'validations' do
    it { should validate_presence_of(:name) }
    it { should validate_presence_of(:code) }
    it { should validate_presence_of(:start_date) }
    it { should validate_presence_of(:end_date) }
    it { should validate_presence_of(:canvas_course_id) }
    it { should validate_uniqueness_of(:canvas_course_id).scoped_to(:user_id) }
  end
  
  describe 'scopes' do
    before do
      create(:course, user: user, active: true, current_term: true, name: 'B Course')
      create(:course, user: user, active: true, current_term: false, name: 'A Course')
      create(:course, user: user, active: false, current_term: false)
      create(:course, user: user, active: true, end_date: Date.today + 7.days)
    end
    
    it 'active scope returns only active courses' do
      expect(Course.active.count).to eq(3)
    end
    
    it 'inactive scope returns only inactive courses' do
      expect(Course.inactive.count).to eq(1)
    end
    
    it 'current_term scope returns only current term courses' do
      expect(Course.current_term.count).to eq(1)
    end
    
    it 'ordered_by_name scope orders courses by name' do
      expect(Course.ordered_by_name.first.name).to eq('A Course')
    end
    
    it 'ordered_by_end_date scope orders courses by end date' do
      expect(Course.ordered_by_end_date.first.end_date).to be <= Course.ordered_by_end_date.last.end_date
    end
    
    it 'ending_soon scope returns courses ending within 14 days' do
      expect(Course.ending_soon.count).to eq(1)
    end
  end
  
  describe '#calculate_current_grade' do
    context 'with completed tasks' do
      before do
        create(:task, course: course, completed: true, score: 85, weight: 100)
        create(:task, course: course, completed: true, score: 90, weight: 100)
      end
      
      it 'calculates and updates current grade' do
        expect(course.calculate_current_grade).to eq(87.5) # (85 + 90) / (100 + 100) * 100
        expect(course.reload.current_grade).to eq(87.5)
      end
    end
    
    context 'with no completed tasks' do
      it 'returns nil' do
        expect(course.calculate_current_grade).to be_nil
      end
    end
    
    context 'with completed tasks but missing scores' do
      before do
        create(:task, course: course, completed: true, score: nil, weight: 100)
      end
      
      it 'ignores tasks with missing scores' do
        expect(course.calculate_current_grade).to be_nil
      end
    end
  end
  
  describe '#upcoming_deadlines' do
    before do
      create(:task, course: course, due_date: Date.today + 2.days)
      create(:task, course: course, due_date: Date.today + 10.days)
    end
    
    it 'returns tasks due within specified days' do
      expect(course.upcoming_deadlines(7).count).to eq(1)
      expect(course.upcoming_deadlines(14).count).to eq(2)
    end
  end
  
  describe '#remaining_tasks_count' do
    before do
      create(:task, course: course, completed: false)
      create(:task, course: course, completed: false)
      create(:task, course: course, completed: true)
    end
    
    it 'returns count of incomplete tasks' do
      expect(course.remaining_tasks_count).to eq(2)
    end
  end
  
  describe '#progress_percentage' do
    before do
      create(:task, course: course, completed: false)
      create(:task, course: course, completed: true)
      create(:task, course: course, completed: true)
    end
    
    it 'calculates percentage of completed tasks' do
      expect(course.progress_percentage).to eq(66.7) # 2/3 * 100 = 66.6666...
    end
    
    context 'with no tasks' do
      let(:empty_course) { create(:course, user: user) }
      
      it 'returns 0' do
        expect(empty_course.progress_percentage).to eq(0)
      end
    end
  end
  
  describe '#has_overdue_tasks?' do
    context 'with overdue tasks' do
      before do
        create(:task, course: course, due_date: Date.yesterday, completed: false)
      end
      
      it 'returns true' do
        expect(course.has_overdue_tasks?).to be true
      end
    end
    
    context 'with no overdue tasks' do
      before do
        create(:task, course: course, due_date: Date.tomorrow, completed: false)
      end
      
      it 'returns false' do
        expect(course.has_overdue_tasks?).to be false
      end
    end
  end
  
  describe '#summary' do
    before do
      create(:task, course: course, completed: true)
      create(:task, course: course, completed: false)
      create(:task, course: course, completed: false, due_date: Date.yesterday)
      course.update(current_grade: 85.5)
    end
    
    it 'returns a hash with course summary stats' do
      summary = course.summary
      expect(summary[:total_tasks]).to eq(3)
      expect(summary[:completed_tasks]).to eq(1)
      expect(summary[:remaining_tasks]).to eq(2)
      expect(summary[:current_grade]).to eq(85.5)
      expect(summary[:overdue_count]).to eq(1)
      expect(summary[:progress]).to eq(33.3) # 1/3 * 100 = 33.3333...
    end
  end
  
  describe '.sync_from_canvas' do
    let(:canvas_course) do
      double(
        id: '12345',
        name: 'Introduction to Programming',
        course_code: 'CS101',
        start_at: Date.today,
        end_at: Date.today + 3.months,
        html_url: 'https://canvas.example.com/courses/12345',
        workflow_state: 'available'
      )
    end
    
    it 'creates a new course if it does not exist' do
      expect {
        Course.sync_from_canvas(user, canvas_course)
      }.to change(Course, :count).by(1)
    end
    
    it 'updates an existing course' do
      existing = create(:course, user: user, canvas_course_id: '12345', name: 'Old Name')
      Course.sync_from_canvas(user, canvas_course)
      expect(existing.reload.name).to eq('Introduction to Programming')
    end
    
    it 'sets attributes from canvas course' do
      course = Course.sync_from_canvas(user, canvas_course)
      expect(course.name).to eq('Introduction to Programming')
      expect(course.code).to eq('CS101')
      expect(course.active).to be true
    end
  end
  
  describe '#sync_assignments_from_canvas' do
    let(:canvas_api) { double }
    let(:canvas_assignments) { [double] }
    
    before do
      allow(canvas_api).to receive(:get_course_assignments).and_return(canvas_assignments)
      allow(Task).to receive(:sync_from_canvas)
    end
    
    it 'fetches assignments from canvas API' do
      expect(canvas_api).to receive(:get_course_assignments).with(course.canvas_course_id)
      course.sync_assignments_from_canvas(canvas_api)
    end
    
    it 'syncs each assignment to a task' do
      expect(Task).to receive(:sync_from_canvas).with(course.user, canvas_assignments.first)
      course.sync_assignments_from_canvas(canvas_api)
    end
  end
  
  describe '.is_current_term?' do
    context 'when course has ended within 30 days' do
      let(:canvas_course) { double(end_at: Date.today - 15.days) }
      
      it 'returns true' do
        expect(Course.is_current_term?(canvas_course)).to be true
      end
    end
    
    context 'when course has not ended yet' do
      let(:canvas_course) { double(end_at: Date.today + 15.days) }
      
      it 'returns true' do
        expect(Course.is_current_term?(canvas_course)).to be true
      end
    end
    
    context 'when course ended more than 30 days ago' do
      let(:canvas_course) { double(end_at: Date.today - 45.days) }
      
      it 'returns false' do
        expect(Course.is_current_term?(canvas_course)).to be false
      end
    end
    
    context 'when course has no end date' do
      let(:canvas_course) { double(end_at: nil) }
      
      it 'returns false' do
        expect(Course.is_current_term?(canvas_course)).to be false
      end
    end
  end
end
