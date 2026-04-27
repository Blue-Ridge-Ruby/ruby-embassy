class CreateHackProjects < ActiveRecord::Migration[8.1]
  def change
    create_table :hack_projects do |t|
      t.references :schedule_item, null: false, foreign_key: true
      t.references :host, null: false, foreign_key: { to_table: :users }
      t.string :title, null: false
      t.string :repo_url, null: false
      t.text :description
      t.string :contributors_guide_url
      t.integer :skill_level

      t.timestamps
    end
  end
end
