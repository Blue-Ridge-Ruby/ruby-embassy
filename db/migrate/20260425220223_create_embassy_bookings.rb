class CreateEmbassyBookings < ActiveRecord::Migration[8.1]
  def change
    create_table :embassy_bookings do |t|
      t.references :user,          null: false, foreign_key: true
      t.references :schedule_item, null: false, foreign_key: true
      t.references :plan_item,     null: false, foreign_key: true
      t.string     :mode,          null: false
      t.string     :state,         null: false, default: "confirmed"

      t.timestamps
    end

    add_index :embassy_bookings, [ :user_id, :schedule_item_id ], unique: true
  end
end
