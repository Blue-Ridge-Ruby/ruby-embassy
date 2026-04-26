class Admin::EmbassyApplicationsController < AdminController
  ACTIVE_SORTS = {
    "appointment" => "schedule_items.day ASC, schedule_items.sort_time ASC",
    "name"        => "users.last_name ASC, users.first_name ASC",
    "serial"      => "embassy_applications.serial ASC"
  }.freeze

  DELIVERED_SORTS = ACTIVE_SORTS.merge(
    "delivered" => "embassy_applications.passport_received_at DESC"
  ).freeze

  def index
    @sort  = ACTIVE_SORTS.key?(params[:sort]) ? params[:sort] : "appointment"
    @query = params[:q].to_s.strip
    @applications = filtered_scope
      .where(passport_received_at: nil)
      .reorder(Arel.sql(ACTIVE_SORTS[@sort]))
  end

  def delivered
    @sort  = DELIVERED_SORTS.key?(params[:sort]) ? params[:sort] : "delivered"
    @query = params[:q].to_s.strip
    @applications = filtered_scope
      .where.not(passport_received_at: nil)
      .reorder(Arel.sql(DELIVERED_SORTS[@sort]))
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

  def mark_received
    application = EmbassyApplication.find_by!(serial: params[:id])
    application.update!(passport_received_at: Time.current)
    redirect_back fallback_location: admin_embassy_applications_path,
                  notice: "Marked #{application.serial} as delivered."
  end

  def unmark_received
    application = EmbassyApplication.find_by!(serial: params[:id])
    application.update!(passport_received_at: nil)
    redirect_back fallback_location: delivered_admin_embassy_applications_path,
                  notice: "Moved #{application.serial} back to the active queue."
  end

  private

  def filtered_scope
    scope = EmbassyApplication
      .submitted
      .joins(embassy_booking: [ :user, :schedule_item ])
      .includes(:notary_profile, embassy_booking: [ :user, :schedule_item ])

    return scope if params[:q].blank?

    term = "%#{params[:q].strip}%"
    scope.where(
      "users.first_name ILIKE :t OR users.last_name ILIKE :t OR users.email ILIKE :t OR embassy_applications.serial ILIKE :t",
      t: term
    )
  end

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
