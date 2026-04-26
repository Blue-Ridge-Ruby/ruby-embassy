class AddMaxLengthToQuestions < ActiveRecord::Migration[8.1]
  def change
    add_column :questions, :max_length, :integer
  end
end
