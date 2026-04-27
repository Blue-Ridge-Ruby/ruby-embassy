class CreateHackProjectSignups < ActiveRecord::Migration[8.1]
  def change
    create_table :hack_project_signups do |t|
      t.references :user, null: false, foreign_key: true
      t.references :hack_project, null: false, foreign_key: true
      t.references :schedule_item, null: false, foreign_key: true
      t.integer :role, null: false

      t.timestamps
    end

    add_index :hack_project_signups, %i[user_id schedule_item_id], unique: true
  end
end
