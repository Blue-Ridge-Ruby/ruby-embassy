class Admin::EmbassyQuestionsController < AdminController
  before_action :set_question, only: %i[edit update destroy]

  def index
    @questions = Question
      .left_joins(:embassy_application_answers)
      .group("questions.id")
      .select("questions.*, COUNT(DISTINCT embassy_application_answers.embassy_application_id) AS computed_usage_count")
      .order(:section, :position)

    @questions_by_section = @questions.group_by(&:section)
    @notary_pool = NotaryProfile.order(:external_id)
  end

  def new
    @question = Question.new(section: 1, field_type: "short", scope: "common", required: false, status: "active", options: [])
  end

  def create
    @question = Question.new(question_params)
    if @question.save
      redirect_to admin_embassy_questions_path,
                  notice: "Question added to the bank."
    else
      render :new, status: :unprocessable_content
    end
  end

  def edit
  end

  def update
    if @question.update(question_params)
      redirect_to admin_embassy_questions_path,
                  notice: "Question updated."
    else
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    @question.update!(status: "archived")
    redirect_to admin_embassy_questions_path,
                notice: "Question archived."
  end

  private

  def set_question
    @question = Question.find(params[:id])
  end

  def question_params
    permitted = params.require(:question).permit(
      :external_id, :section, :position, :label, :help, :placeholder,
      :field_type, :required, :scope, :status, :options_text
    )
    parse_options(permitted)
  end

  def parse_options(permitted)
    text = permitted.delete(:options_text)
    permitted[:options] = text.to_s.split(/\r?\n/).map(&:strip).reject(&:blank?) if text
    permitted
  end
end
