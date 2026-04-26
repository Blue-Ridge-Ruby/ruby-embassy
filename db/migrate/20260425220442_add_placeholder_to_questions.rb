class AddPlaceholderToQuestions < ActiveRecord::Migration[8.1]
  def change
    add_column :questions, :placeholder, :string
  end
end
