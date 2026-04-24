class Admin::EmbassyQuestionsController < AdminController
  def index
    @questions = FakeEmbassy.question_bank
    @sections  = FakeEmbassy.sample_questions.map { |s| [ s[:number], s[:title] ] }
  end

  def new
    @question = { id: "", section: 1, label: "", type: :short,
                  required: false, help: "", status: "active" }
  end

  def create
    redirect_to admin_embassy_questions_path,
                notice: "Question added to the bank."
  end

  def edit
    @question = FakeEmbassy.find_question(params[:id])
  end

  def update
    redirect_to admin_embassy_questions_path,
                notice: "Question updated."
  end

  def destroy
    redirect_to admin_embassy_questions_path,
                notice: "Question archived."
  end
end
