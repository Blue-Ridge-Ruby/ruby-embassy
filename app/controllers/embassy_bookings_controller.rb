class EmbassyBookingsController < ApplicationController
  def new
    @schedule_item = ScheduleItem.find(params[:schedule_item_id])
    @block_mode    = FakeEmbassy.mode_for(@schedule_item.id)
    @chosen_mode   = params[:mode].presence || (@block_mode == "both" ? nil : @block_mode)
    @capacity      = FakeEmbassy.capacity_for(@schedule_item.id)
    @seats_taken   = FakeEmbassy.seats_taken_for(@schedule_item.id)
  end

  def create
    @schedule_item = ScheduleItem.find(params[:schedule_item_id])
    mode           = params[:mode].presence || "new_passport"
    @plan_item     = current_user.plan_items.find_or_create_by!(schedule_item: @schedule_item)

    if mode == "stamping"
      @chosen_mode = "stamping"
      render :create
    else
      redirect_to new_embassy_application_path(plan_item_id: @plan_item.id)
    end
  end
end
