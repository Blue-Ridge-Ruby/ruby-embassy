class AddHackRoleToPlanItems < ActiveRecord::Migration[8.1]
  def change
    add_column :plan_items, :hack_role, :integer
  end
end
