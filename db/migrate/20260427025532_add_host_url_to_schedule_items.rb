class AddHostUrlToScheduleItems < ActiveRecord::Migration[8.1]
  def change
    add_column :schedule_items, :host_url, :string, if_not_exists: true
  end
end
