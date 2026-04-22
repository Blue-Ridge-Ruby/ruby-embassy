class CreateConfigurations < ActiveRecord::Migration[8.1]
  def change
    create_table :configurations do |t|
      t.string :name, null: false
      t.string :value

      t.timestamps
    end

    add_index :configurations, :name, unique: true
  end
end
