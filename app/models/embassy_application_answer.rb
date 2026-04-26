class EmbassyApplicationAnswer < ApplicationRecord
  belongs_to :embassy_application
  belongs_to :question

  validates :question_id, uniqueness: { scope: :embassy_application_id }

  def display_value
    case question.field_type
    when "checkbox_group" then value_array
    when "checkbox"       then value_text == "true"
    else value_text
    end
  end

  def blank_value?
    value_text.blank? && value_array.blank?
  end
end
