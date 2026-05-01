class EmbassyApplication < ApplicationRecord
  belongs_to :embassy_booking
  belongs_to :notary_profile, optional: true
  has_many :embassy_application_answers, dependent: :destroy
  has_one :user, through: :embassy_booking
  has_one :schedule_item, through: :embassy_booking

  enum :state, { draft: "draft", submitted: "submitted" }

  validates :serial, presence: true, uniqueness: true
  validate :required_questions_answered, on: :submit

  before_validation :assign_serial, on: :create
  after_update_commit :bust_annual_report_cache, if: :saved_change_to_state?

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

  def required_questions_for_form
    common = Question.active.where(section: [ 1, 2, 4, 5 ], required: true).ordered
    drawn  = Question.active.where(external_id: drawn_question_ids, required: true).ordered
    common.to_a + drawn.to_a
  end

  private

  def assign_serial
    self.serial ||= EmbassyApplicationSerialGenerator.next
  end

  def bust_annual_report_cache
    Rails.cache.delete("annual_report:v1") if submitted?
  end

  def required_questions_answered
    answers_by_qid = embassy_application_answers.includes(:question).index_by(&:question_id)

    required_questions_for_form.each do |question|
      answer = answers_by_qid[question.id]
      if answer.nil? || !answer.satisfies_required?
        errors.add(:base, "#{question.label} is required")
      end
    end
  end
end
