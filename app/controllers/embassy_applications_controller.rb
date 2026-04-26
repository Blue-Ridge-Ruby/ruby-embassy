class EmbassyApplicationsController < ApplicationController
  before_action :set_application_for_show, only: %i[show edit update]

  def new
    @booking = current_user.embassy_bookings.find(params[:embassy_booking_id])
    unless @booking.application_required?
      redirect_to plan_path,
                  notice: "Stamping appointments don't require an application." and return
    end

    @application = @booking.embassy_application || @booking.create_embassy_application!
    EmbassyApplicationDraw.call(@application)

    if @application.submitted?
      redirect_to embassy_application_path(@application) and return
    end

    @sections = sections_for(@application)
    @schedule_item = @booking.schedule_item
  end

  def create
    @booking = current_user.embassy_bookings.find(params[:embassy_booking_id])
    @application = @booking.embassy_application || @booking.create_embassy_application!
    EmbassyApplicationDraw.call(@application)

    save_answers!(@application, params[:q] || {})
    finalize_or_redirect(@application)
  end

  def show
    respond_to do |format|
      format.html do
        @sections = sections_for(@application)
        @schedule_item = @application.schedule_item
        @booking = @application.embassy_booking
        @notary = @application.notary_profile
      end
      format.pdf do
        send_data PassportApplicationPdf.new(application: @application).render,
                  filename: "#{@application.serial}.pdf",
                  type: "application/pdf",
                  disposition: "attachment"
      end
    end
  end

  def edit
    if @application.submitted?
      redirect_to embassy_application_path(@application),
                  notice: "This application has already been submitted." and return
    end
    @booking = @application.embassy_booking
    @sections = sections_for(@application)
    @schedule_item = @booking.schedule_item
    render :new
  end

  def update
    if @application.submitted?
      redirect_to embassy_application_path(@application) and return
    end

    save_answers!(@application, params[:q] || {})
    finalize_or_redirect(@application)
  end

  private

  def set_application_for_show
    @application = EmbassyApplication.find_by!(serial: params[:id])
    unless admin? || @application.user == current_user
      raise ActiveRecord::RecordNotFound
    end
  end

  def sections_for(application)
    {
      1 => Question.active.for_section(1).to_a,
      2 => Question.active.for_section(2).to_a,
      3 => application.drawn_questions.to_a,
      4 => Question.active.for_section(4).to_a,
      5 => Question.active.for_section(5).to_a
    }
  end

  def finalize_or_redirect(application)
    if params[:intent] == "submit"
      application.update!(state: "submitted", submitted_at: Time.current)
      redirect_to embassy_application_path(application),
                  notice: "Application submitted. Your serial is #{application.serial}."
    else
      redirect_to plan_path, notice: "Draft saved. Pick up where you left off any time."
    end
  end

  def save_answers!(application, q_params)
    questions_by_external_id = Question.where(external_id: q_params.keys).index_by(&:external_id)

    EmbassyApplicationAnswer.transaction do
      q_params.each do |external_id, raw_value|
        question = questions_by_external_id[external_id]
        next unless question

        answer = application.embassy_application_answers.find_or_initialize_by(question: question)

        if question.field_type == "checkbox_group"
          answer.value_array = Array(raw_value).reject(&:blank?)
          answer.value_text  = nil
        else
          answer.value_text  = raw_value.to_s
          answer.value_array = []
        end

        answer.save!
      end
    end
  end
end
