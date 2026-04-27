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
    @pickups_by_user_id = preload_pickups_for(@applications)
  end

  def delivered
    @sort  = DELIVERED_SORTS.key?(params[:sort]) ? params[:sort] : "delivered"
    @query = params[:q].to_s.strip
    @applications = filtered_scope
      .where.not(passport_received_at: nil)
      .reorder(Arel.sql(DELIVERED_SORTS[@sort]))
    @pickups_by_user_id = preload_pickups_for(@applications)
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
    @pickup_booking  = @booking.user.embassy_bookings.active.passport_pickup.first
    @pickup_blocks   = ScheduleItem.embassy.where(offers_passport_pickup: true).ordered

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

  def schedule_pickup
    application   = EmbassyApplication.find_by!(serial: params[:id])
    applicant     = application.embassy_booking.user
    schedule_item = ScheduleItem.embassy.find(params[:schedule_item_id])

    unless schedule_item.offers_passport_pickup?
      redirect_back fallback_location: admin_embassy_application_path(application.serial),
                    alert: "That block isn't set up for passport pickup."
      return
    end

    result = ActiveRecord::Base.transaction do
      ScheduleItem.lock.find(schedule_item.id)
      next :full if schedule_item.full_for?("passport_pickup")

      plan_item = applicant.plan_items.find_or_create_by!(schedule_item: schedule_item)
      booking   = EmbassyBooking.find_or_initialize_by(user: applicant, schedule_item: schedule_item)
      booking.assign_attributes(
        plan_item: plan_item,
        mode:      "passport_pickup",
        state:     "confirmed"
      )
      booking.save!
      booking
    end

    if result == :full
      redirect_back fallback_location: admin_embassy_application_path(application.serial),
                    alert: "That pickup block is full."
    else
      redirect_to admin_embassy_application_path(application.serial),
                  notice: "Pickup scheduled for #{applicant.full_name}."
    end
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

  def preload_pickups_for(applications)
    user_ids = applications.map { |a| a.embassy_booking.user_id }.uniq
    EmbassyBooking
      .active
      .passport_pickup
      .where(user_id: user_ids)
      .includes(:schedule_item)
      .index_by(&:user_id)
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
