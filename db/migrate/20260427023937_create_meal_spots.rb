class CreateMealSpots < ActiveRecord::Migration[8.1]
  def change
    create_table :meal_spots do |t|
      t.references :schedule_item, null: false, foreign_key: true
      t.references :created_by, null: false, foreign_key: { to_table: :users }
      t.string :name, null: false
      t.string :map_url
      t.string :meet_up_spot
      t.string :contact_info

      t.timestamps
    end

    # Case-insensitive uniqueness of spot name within a single meal event,
    # so two attendees can't independently add "Hattie B's" and "hattie b's".
    add_index :meal_spots,
              "schedule_item_id, lower(name)",
              unique: true,
              name: "index_meal_spots_on_schedule_item_id_and_lower_name"
  end
end
