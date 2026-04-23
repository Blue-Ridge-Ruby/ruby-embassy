class CreateScheduleItems < ActiveRecord::Migration[8.1]
  def change
    create_table :schedule_items do |t|
      t.string  :slug
      t.string  :day,        null: false
      t.string  :time_label
      t.integer :sort_time
      t.string  :title,      null: false
      t.string  :host
      t.string  :location
      t.text    :description
      t.integer :kind,       null: false
      t.boolean :flexible,   null: false, default: false
      t.references :created_by, foreign_key: { to_table: :users }, null: true
      t.boolean :is_public,  null: false, default: false

      t.timestamps
    end

    add_index :schedule_items, :slug, unique: true, where: "slug IS NOT NULL"
    add_index :schedule_items, [ :day, :sort_time ]
    add_index :schedule_items, :is_public
  end
end
