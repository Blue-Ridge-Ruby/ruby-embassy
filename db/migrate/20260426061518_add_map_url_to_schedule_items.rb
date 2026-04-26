class AddMapUrlToScheduleItems < ActiveRecord::Migration[8.1]
  def change
    add_column :schedule_items, :map_url, :string
  end
end
