class AddContactMethodToMealSpotRsvps < ActiveRecord::Migration[8.1]
  def change
    add_column :meal_spot_rsvps, :contact_method, :string
  end
end
