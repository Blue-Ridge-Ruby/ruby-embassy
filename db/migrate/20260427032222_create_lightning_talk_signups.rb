class CreateLightningTalkSignups < ActiveRecord::Migration[8.1]
  def change
    create_table :lightning_talk_signups do |t|
      t.references :user, null: false, foreign_key: true
      t.references :schedule_item, null: false, foreign_key: true
      t.string :talk_title
      t.text :talk_description
      t.string :slides_url
      t.integer :position, null: false

      t.timestamps
    end

    add_index :lightning_talk_signups, [ :user_id, :schedule_item_id ], unique: true
    add_index :lightning_talk_signups, [ :schedule_item_id, :position ], unique: true
  end
end
