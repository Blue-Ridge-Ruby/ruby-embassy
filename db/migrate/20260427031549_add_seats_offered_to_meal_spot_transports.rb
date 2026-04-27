class AddSeatsOfferedToMealSpotTransports < ActiveRecord::Migration[8.1]
  def change
    # Nullable: only meaningful for driving transports. Validation in the
    # model enforces presence + non-negativity when mode == driving.
    add_column :meal_spot_transports, :seats_offered, :integer
  end
end
