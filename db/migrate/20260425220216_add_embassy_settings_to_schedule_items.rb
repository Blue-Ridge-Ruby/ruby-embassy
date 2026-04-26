class AddEmbassySettingsToScheduleItems < ActiveRecord::Migration[8.1]
  def change
    add_column :schedule_items, :embassy_mode, :string
    add_column :schedule_items, :embassy_capacity, :integer

    add_index :schedule_items, [:kind, :embassy_mode]
  end
end
