class CreateAssignments < ActiveRecord::Migration[8.0]
  def change
    create_table :assignments do |t|
      t.string :title
      t.string :course
      t.date :due_date

      t.timestamps
    end
  end
end
