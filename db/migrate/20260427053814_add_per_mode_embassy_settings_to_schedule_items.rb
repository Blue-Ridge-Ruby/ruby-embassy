class AddPerModeEmbassySettingsToScheduleItems < ActiveRecord::Migration[8.1]
  def up
    add_column :schedule_items, :offers_new_passport,    :boolean, default: false, null: false
    add_column :schedule_items, :offers_stamping,        :boolean, default: false, null: false
    add_column :schedule_items, :offers_passport_pickup, :boolean, default: false, null: false
    add_column :schedule_items, :new_passport_capacity,    :integer
    add_column :schedule_items, :stamping_capacity,        :integer
    add_column :schedule_items, :passport_pickup_capacity, :integer

    execute <<~SQL.squish
      UPDATE schedule_items
         SET offers_new_passport   = TRUE,
             new_passport_capacity = embassy_capacity
       WHERE embassy_mode IN ('new_passport', 'both')
    SQL

    execute <<~SQL.squish
      UPDATE schedule_items
         SET offers_stamping   = TRUE,
             stamping_capacity = embassy_capacity
       WHERE embassy_mode IN ('stamping', 'both')
    SQL

    remove_column :schedule_items, :embassy_mode
    remove_column :schedule_items, :embassy_capacity
  end

  def down
    add_column :schedule_items, :embassy_mode,     :string
    add_column :schedule_items, :embassy_capacity, :integer

    execute <<~SQL.squish
      UPDATE schedule_items
         SET embassy_mode = CASE
                              WHEN offers_new_passport AND offers_stamping THEN 'both'
                              WHEN offers_new_passport THEN 'new_passport'
                              WHEN offers_stamping THEN 'stamping'
                              ELSE NULL
                            END,
             embassy_capacity = COALESCE(new_passport_capacity, stamping_capacity)
    SQL

    remove_column :schedule_items, :passport_pickup_capacity
    remove_column :schedule_items, :stamping_capacity
    remove_column :schedule_items, :new_passport_capacity
    remove_column :schedule_items, :offers_passport_pickup
    remove_column :schedule_items, :offers_stamping
    remove_column :schedule_items, :offers_new_passport
  end
end
