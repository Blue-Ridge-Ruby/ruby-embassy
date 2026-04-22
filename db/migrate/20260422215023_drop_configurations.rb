class DropConfigurations < ActiveRecord::Migration[8.1]
  def change
    drop_table :configurations do |t|
      t.string :name, null: false
      t.string :value

      t.timestamps
      t.index [ :name ], unique: true
    end
  end
end
