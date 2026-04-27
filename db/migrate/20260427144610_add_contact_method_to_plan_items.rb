class AddContactMethodToPlanItems < ActiveRecord::Migration[8.1]
  def change
    add_column :plan_items, :contact_method, :string
  end
end
