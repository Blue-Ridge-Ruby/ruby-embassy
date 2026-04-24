class CreatePlanItems < ActiveRecord::Migration[8.1]
  def change
    create_table :plan_items do |t|
      t.references :user, null: false, foreign_key: true
      t.references :schedule_item, null: false, foreign_key: true
      t.text :notes

      t.timestamps
    end

    add_index :plan_items, [ :user_id, :schedule_item_id ], unique: true
  end
end
