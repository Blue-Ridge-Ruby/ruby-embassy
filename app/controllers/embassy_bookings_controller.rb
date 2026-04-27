class EmbassyBookingsController < ApplicationController
  SELF_SERVICE_MODES = %w[new_passport stamping].freeze

  def new
    @schedule_item = ScheduleItem.embassy.find(params[:schedule_item_id])
    @block_mode    = self_service_block_mode || "new_passport"
    @chosen_mode   = params[:mode].presence || (@block_mode == "both" ? nil : @block_mode)
    @existing_booking = current_user.embassy_bookings.find_by(schedule_item: @schedule_item)
    @capacity      = @chosen_mode && SELF_SERVICE_MODES.include?(@chosen_mode) ? @schedule_item.capacity_for(@chosen_mode) : nil
    @seats_taken   = @chosen_mode && SELF_SERVICE_MODES.include?(@chosen_mode) ? @schedule_item.seats_taken_for(@chosen_mode) : nil
  end

  def create
    @schedule_item = ScheduleItem.embassy.find(params[:schedule_item_id])
    mode           = resolved_mode

    unless SELF_SERVICE_MODES.include?(mode) && @schedule_item.offers?(mode)
      redirect_to new_embassy_booking_path(schedule_item_id: @schedule_item.id),
                  alert: "That booking option isn't available."
      return
    end

    @booking = ActiveRecord::Base.transaction do
      ScheduleItem.lock.find(@schedule_item.id)

      if @schedule_item.full_for?(mode)
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
      redirect_to embassy_booking_path(@booking)
    else
      redirect_to new_embassy_application_path(embassy_booking_id: @booking.id)
    end
  end

  def show
    @booking       = current_user.embassy_bookings.find(params[:id])
    @schedule_item = @booking.schedule_item
    @chosen_mode   = @booking.mode
    render :create
  end

  private

  # Returns "both", "new_passport", "stamping", or nil — never "passport_pickup"
  # since pickup is admin-only and never exposed via the user-facing flow.
  def self_service_block_mode
    new_passport = @schedule_item.offers_new_passport?
    stamping     = @schedule_item.offers_stamping?
    return "both"          if new_passport && stamping
    return "new_passport"  if new_passport
    return "stamping"      if stamping
    nil
  end

  def resolved_mode
    requested = params[:mode].presence
    return requested if SELF_SERVICE_MODES.include?(requested) && @schedule_item.offers?(requested)
    if @schedule_item.offers_new_passport? && !@schedule_item.offers_stamping?
      "new_passport"
    elsif @schedule_item.offers_stamping? && !@schedule_item.offers_new_passport?
      "stamping"
    else
      "new_passport"
    end
  end
end
