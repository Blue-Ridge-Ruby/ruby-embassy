class Admin::EmbassyApplicationsController < AdminController
  def index
    @applications = EmbassyApplication
      .submitted
      .includes(:notary_profile, embassy_booking: [ :user, :schedule_item ])
      .order(submitted_at: :desc)
  end

  def show
    @application = EmbassyApplication.includes(
      :notary_profile,
      embassy_application_answers: :question,
      embassy_booking: [ :user, :schedule_item ]
    ).find_by!(serial: params[:id])

    @booking       = @application.embassy_booking
    @schedule_item = @application.schedule_item
    @notary        = @application.notary_profile
    @sections      = sections_for(@application)

    respond_to do |format|
      format.html
      format.pdf do
        send_data PassportApplicationPdf.new(application: @application).render,
                  filename: "#{@application.serial}.pdf",
                  type: "application/pdf",
                  disposition: "attachment"
      end
    end
  end

  private

  def sections_for(application)
    {
      1 => Question.for_section(1).to_a,
      2 => Question.for_section(2).to_a,
      3 => application.drawn_questions.to_a,
      4 => Question.for_section(4).to_a,
      5 => Question.for_section(5).to_a
    }
  end
end
