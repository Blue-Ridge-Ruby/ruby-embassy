class CreateMealSpotRsvps < ActiveRecord::Migration[8.1]
  def change
    create_table :meal_spot_rsvps do |t|
      t.references :user, null: false, foreign_key: true
      t.references :meal_spot_transport, null: false, foreign_key: true
      t.references :schedule_item, null: false, foreign_key: true

      t.timestamps
    end

    # One spot per user per meal event. schedule_item_id is denormalized
    # from meal_spot_transport.meal_spot.schedule_item so the DB can enforce
    # this without a trigger.
    add_index :meal_spot_rsvps, [ :user_id, :schedule_item_id ], unique: true
  end
end
