class CreateQuestions < ActiveRecord::Migration[8.1]
  def change
    create_table :questions do |t|
      t.string  :external_id, null: false
      t.integer :section,     null: false
      t.integer :position,    null: false, default: 0
      t.text    :label,       null: false
      t.text    :help
      t.string  :field_type,  null: false
      t.boolean :required,    null: false, default: false
      t.string  :scope,       null: false, default: "common"
      t.string  :status,      null: false, default: "active"
      t.jsonb   :options,     null: false, default: []

      t.timestamps
    end

    add_index :questions, :external_id, unique: true
    add_index :questions, [ :section, :position ]
    add_index :questions, [ :scope, :status ]
  end
end
