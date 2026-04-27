class MealSpotRsvpsController < ApplicationController
  before_action :set_meal
  before_action :set_meal_spot

  # Handles four cases in one endpoint:
  #   1. First-time RSVP, joining an existing transport
  #   2. First-time RSVP, starting a new transport (new mode at this spot)
  #   3. Switching from another spot for the same meal (existing transport)
  #   4. Switching from another spot for the same meal (new transport)
  # Switching = atomically destroy any prior RSVP for this user+meal,
  # then create the new one. The (user_id, schedule_item_id) unique index
  # is the safety net; this controller is the happy path.
  def create
    existing_rsvp = MealSpotRsvp.find_by(user: current_user, schedule_item: @meal)
    if existing_rsvp&.locked_in?
      return redirect_to schedule_item_meal_spots_path(@meal),
                         alert: existing_rsvp.lock_reason
    end

    MealSpotRsvp.transaction do
      MealSpotRsvp.where(user: current_user, schedule_item: @meal).destroy_all
      transport = resolve_transport!
      transport.rsvps.create!(user: current_user)
    end
    redirect_to schedule_item_meal_spots_path(@meal), notice: "You're in."
  rescue ActiveRecord::RecordInvalid => e
    redirect_to schedule_item_meal_spots_path(@meal),
                alert: "Couldn't RSVP: #{e.message}"
  end

  def destroy
    rsvp = MealSpotRsvp.find_by!(id: params[:id], user: current_user)
    if rsvp.locked_in?
      return redirect_to schedule_item_meal_spots_path(@meal),
                         alert: rsvp.lock_reason
    end
    rsvp.destroy
    redirect_to schedule_item_meal_spots_path(@meal), notice: "Removed your RSVP."
  end

  private

  def set_meal
    @meal = ScheduleItem.visible_to(current_user).find(params[:schedule_item_id])
    raise ActiveRecord::RecordNotFound unless @meal.meal?
  end

  def set_meal_spot
    @meal_spot = @meal.meal_spots.find(params[:meal_spot_id])
  end

  # If the user submits the "add a different way" form for a mode that
  # already exists at this spot, treat it as a switch into the existing
  # transport rather than failing with a uniqueness error. Same outcome
  # the user wants either way: be on the walking (or driving) transport.
  def resolve_transport!
    if params[:transport_id].present?
      @meal_spot.transports.find(params[:transport_id])
    elsif (existing = @meal_spot.transports.find_by(mode: params[:mode]))
      existing
    else
      @meal_spot.transports.create!(
        mode:          params[:mode],
        departs_at:    params[:departs_at],
        seats_offered: params[:seats_offered],
        meet_up_spot:  params[:meet_up_spot]
      )
    end
  end
end
