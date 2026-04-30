class Admin::EmbassyApplicationsController < AdminController
  ACTIVE_SORTABLE_COLUMNS = {
    "appointment" => "schedule_items.day, schedule_items.sort_time",
    "name"        => "users.last_name, users.first_name",
    "serial"      => "embassy_applications.serial",
    "submitted"   => "embassy_applications.submitted_at"
  }.freeze
  ACTIVE_DEFAULT_ORDER = "schedule_items.day ASC, schedule_items.sort_time ASC"

  DELIVERED_SORTABLE_COLUMNS = ACTIVE_SORTABLE_COLUMNS.merge(
    "delivered" => "embassy_applications.passport_received_at"
  ).freeze
  DELIVERED_DEFAULT_ORDER = "embassy_applications.passport_received_at DESC"

  def index
    order_clause = apply_sort(ACTIVE_SORTABLE_COLUMNS) || ACTIVE_DEFAULT_ORDER
    @query = params[:q].to_s.strip
    @applications = filtered_scope
      .where(passport_received_at: nil)
      .reorder(Arel.sql(order_clause))
    @pickups_by_user_id = preload_pickups_for(@applications)
  end

  def delivered
    order_clause = apply_sort(DELIVERED_SORTABLE_COLUMNS) || DELIVERED_DEFAULT_ORDER
    @query = params[:q].to_s.strip
    @applications = filtered_scope
      .where.not(passport_received_at: nil)
      .reorder(Arel.sql(order_clause))
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

  def destroy
    application = EmbassyApplication.find_by!(serial: params[:id])
    booking = application.embassy_booking
    applicant_name = booking.user.full_name
    serial = application.serial
    # Cascade via plan_item: deleting the application alone leaves a stale booking + plan slot that breaks the user's plan view.
    booking.plan_item.destroy!
    redirect_to admin_embassy_applications_path,
                notice: "Deleted application #{serial} for #{applicant_name}. They'll need to rebook the appointment from the schedule."
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
