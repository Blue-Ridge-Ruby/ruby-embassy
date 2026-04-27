class AddUniqueHostIndexToHackProjects < ActiveRecord::Migration[8.1]
  def change
    add_index :hack_projects, %i[host_id schedule_item_id], unique: true
  end
end
