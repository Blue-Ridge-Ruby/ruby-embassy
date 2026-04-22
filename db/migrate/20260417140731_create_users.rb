class CreateUsers < ActiveRecord::Migration[8.1]
  def change
    create_table :users do |t|
      t.string  :email, null: false
      t.string  :first_name
      t.string  :last_name
      t.integer :role, default: 0, null: false
      t.string  :tito_account_slug
      t.string  :tito_event_slug
      t.string  :tito_ticket_slug

      t.timestamps
    end

    add_index :users, :email, unique: true
    add_index :users, :tito_ticket_slug, unique: true
  end
end
