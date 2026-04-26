class CreateNotaryProfiles < ActiveRecord::Migration[8.1]
  def change
    create_table :notary_profiles do |t|
      t.string :external_id,     null: false
      t.text   :description,     null: false
      t.text   :followup_prompt
      t.string :status,          null: false, default: "active"

      t.timestamps
    end

    add_index :notary_profiles, :external_id, unique: true
  end
end
