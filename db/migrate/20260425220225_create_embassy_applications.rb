class CreateEmbassyApplications < ActiveRecord::Migration[8.1]
  def change
    create_table :embassy_applications do |t|
      t.references :embassy_booking,    null: false, foreign_key: true, index: false
      t.references :notary_profile,     null: true,  foreign_key: true
      t.string     :serial,             null: false
      t.string     :state,              null: false, default: "draft"
      t.datetime   :submitted_at
      t.jsonb      :drawn_question_ids, null: false, default: []

      t.timestamps
    end

    add_index :embassy_applications, :serial, unique: true
    add_index :embassy_applications, :embassy_booking_id, unique: true, name: "index_embassy_applications_on_booking_uniq"
  end
end
