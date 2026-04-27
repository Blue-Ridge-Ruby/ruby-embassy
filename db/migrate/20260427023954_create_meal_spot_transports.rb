class CreateMealSpotTransports < ActiveRecord::Migration[8.1]
  def change
    create_table :meal_spot_transports do |t|
      t.references :meal_spot, null: false, foreign_key: true
      t.integer :mode, null: false
      t.datetime :departs_at, null: false

      t.timestamps
    end

    # One departure time per mode per spot: walkers all leave together,
    # drivers all leave together. Joiners adopt the existing time.
    add_index :meal_spot_transports, [ :meal_spot_id, :mode ], unique: true
  end
end
