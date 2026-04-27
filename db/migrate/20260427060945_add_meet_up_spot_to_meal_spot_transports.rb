class AddMeetUpSpotToMealSpotTransports < ActiveRecord::Migration[8.1]
  def change
    add_column :meal_spot_transports, :meet_up_spot, :string
  end
end
