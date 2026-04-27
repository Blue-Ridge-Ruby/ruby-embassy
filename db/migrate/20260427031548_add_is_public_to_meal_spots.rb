class AddIsPublicToMealSpots < ActiveRecord::Migration[8.1]
  def change
    add_column :meal_spots, :is_public, :boolean, default: true, null: false
    add_index  :meal_spots, [ :schedule_item_id, :is_public ]
  end
end
