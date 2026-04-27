class ChangeMealSpotsCreatedByToNullable < ActiveRecord::Migration[8.1]
  def change
    change_column_null :meal_spots, :created_by_id, true
  end
end
