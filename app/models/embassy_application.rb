class EmbassyApplication < ApplicationRecord
  belongs_to :embassy_booking
  belongs_to :notary_profile, optional: true
  has_many :embassy_application_answers, dependent: :destroy
  has_one :user, through: :embassy_booking
  has_one :schedule_item, through: :embassy_booking

  enum :state, { draft: "draft", submitted: "submitted" }

  validates :serial, presence: true, uniqueness: true

  before_validation :assign_serial, on: :create

  def to_param = serial

  def drawn_questions
    Question.where(external_id: drawn_question_ids).ordered
  end

  def common_questions(section)
    Question.common.active.for_section(section)
  end

  def answer_for(question)
    embassy_application_answers.find_by(question_id: question.id)
  end

  private

  def assign_serial
    self.serial ||= EmbassyApplicationSerialGenerator.next
  end
end
