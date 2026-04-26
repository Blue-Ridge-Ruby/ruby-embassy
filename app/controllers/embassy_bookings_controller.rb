class EmbassyBookingsController < ApplicationController
  def new
    @schedule_item = ScheduleItem.embassy.find(params[:schedule_item_id])
    @block_mode    = @schedule_item.embassy_mode || "new_passport"
    @chosen_mode   = params[:mode].presence || (@block_mode == "both" ? nil : @block_mode)
    @capacity      = @schedule_item.embassy_capacity
    @seats_taken   = @schedule_item.seats_taken
    @existing_booking = current_user.embassy_bookings.find_by(schedule_item: @schedule_item)
  end

  def create
    @schedule_item = ScheduleItem.embassy.find(params[:schedule_item_id])
    mode           = resolved_mode

    @booking = ActiveRecord::Base.transaction do
      ScheduleItem.lock.find(@schedule_item.id)

      if @schedule_item.embassy_capacity.present? && @schedule_item.seats_taken >= @schedule_item.embassy_capacity
        existing = current_user.embassy_bookings.find_by(schedule_item: @schedule_item)
        next existing if existing
        raise ActiveRecord::Rollback, :full
      end

      plan_item = current_user.plan_items.find_or_create_by!(schedule_item: @schedule_item)
      booking = EmbassyBooking.find_or_initialize_by(user: current_user, schedule_item: @schedule_item)
      booking.plan_item = plan_item
      booking.mode      = mode
      booking.state     = "confirmed"
      booking.save!
      booking
    end

    if @booking.nil?
      redirect_to new_embassy_booking_path(schedule_item_id: @schedule_item.id),
                  alert: "This embassy block is full."
      return
    end

    if @booking.stamping?
      @chosen_mode = "stamping"
      render :create
    else
      redirect_to new_embassy_application_path(embassy_booking_id: @booking.id)
    end
  end

  private

  def resolved_mode
    requested = params[:mode].presence
    return requested if EmbassyBooking.modes.key?(requested)
    @schedule_item.embassy_mode == "stamping" ? "stamping" : "new_passport"
  end
end
