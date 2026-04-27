class AddAudienceToScheduleItems < ActiveRecord::Migration[8.1]
  def change
    add_column :schedule_items, :audience, :string, default: "everyone", null: false
    add_index :schedule_items, :audience
  end
end
