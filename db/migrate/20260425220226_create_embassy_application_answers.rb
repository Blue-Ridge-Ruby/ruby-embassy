class CreateEmbassyApplicationAnswers < ActiveRecord::Migration[8.1]
  def change
    create_table :embassy_application_answers do |t|
      t.references :embassy_application, null: false, foreign_key: true
      t.references :question,            null: false, foreign_key: true
      t.text       :value_text
      t.jsonb      :value_array, null: false, default: []

      t.timestamps
    end

    add_index :embassy_application_answers,
              [:embassy_application_id, :question_id],
              unique: true,
              name: "index_embassy_application_answers_on_app_question_uniq"
  end
end
