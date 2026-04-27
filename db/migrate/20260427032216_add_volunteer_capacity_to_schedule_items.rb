class AddVolunteerCapacityToScheduleItems < ActiveRecord::Migration[8.1]
  def change
    add_column :schedule_items, :volunteer_capacity, :integer
  end
end
