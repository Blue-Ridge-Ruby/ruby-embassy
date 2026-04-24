class Admin::EmbassyApplicationsController < AdminController
  def index
    @applications = FakeEmbassy.submitted_applications
  end

  def show
    @application = FakeEmbassy.find_submitted_application(params[:id])
    @sections    = FakeEmbassy.sample_questions
  end
end
