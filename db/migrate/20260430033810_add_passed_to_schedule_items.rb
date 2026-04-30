class AddPassedToScheduleItems < ActiveRecord::Migration[8.1]
  def change
    add_column :schedule_items, :passed, :boolean, default: false, null: false
  end
end
