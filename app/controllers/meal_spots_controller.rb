class MealSpotsController < ApplicationController
  before_action :set_meal
  before_action :set_meal_spot, only: %i[edit update]
  before_action :require_editable!, only: %i[edit update]
  before_action :require_creation_allowed!, only: %i[new create]

  def index
    MealSpot.canonical_for_hosted!(@meal) if @meal.hosted?
    @meal_spots = @meal.meal_spots
                       .where("is_public = TRUE OR created_by_id = ?", current_user.id)
                       .includes(transports: { rsvps: :user })
                       .order(:created_at)
    @current_user_rsvp = MealSpotRsvp.find_by(user: current_user, schedule_item: @meal)
    @current_user_hosted_spot = @meal.meal_spots.find_by(created_by: current_user)
  end

  def new
    @meal_spot = @meal.meal_spots.new
    @transport = MealSpotTransport.new(mode: :walking)
  end

  def create
    @meal_spot = @meal.meal_spots.new(meal_spot_params)
    @meal_spot.created_by = current_user
    @transport = MealSpotTransport.new(transport_params)

    MealSpot.transaction do
      @meal_spot.save!
      @transport.meal_spot = @meal_spot
      @transport.save!
      remove_existing_rsvp_for_meal!
      @transport.rsvps.create!(user: current_user)
    end

    redirect_to schedule_item_meal_spots_path(@meal),
                notice: "Spot added. You're going to #{@meal_spot.name}."
  rescue ActiveRecord::RecordInvalid
    @transport ||= MealSpotTransport.new(mode: :walking)
    render :new, status: :unprocessable_content
  end

  def edit; end

  def update
    if @meal_spot.update(meal_spot_params)
      redirect_to schedule_item_meal_spots_path(@meal), notice: "Spot updated."
    else
      render :edit, status: :unprocessable_content
    end
  end

  private

  def set_meal
    @meal = ScheduleItem.visible_to(current_user).find(params[:schedule_item_id])
    raise ActiveRecord::RecordNotFound unless @meal.meal?
  end

  def set_meal_spot
    @meal_spot = @meal.meal_spots.find(params[:id])
  end

  def require_editable!
    return if @meal_spot.editable_by?(current_user)
    redirect_to schedule_item_meal_spots_path(@meal),
                alert: "This spot can only be edited by an admin once others have RSVPd."
  end

  def require_creation_allowed!
    if @meal.hosted?
      where = @meal.location.presence || @meal.host
      return redirect_to schedule_item_meal_spots_path(@meal),
                         alert: "This meal is hosted at #{where}. " \
                                "Add your way to get there below."
    end

    existing = @meal.meal_spots.find_by(created_by: current_user)
    return unless existing
    redirect_to schedule_item_meal_spots_path(@meal),
                alert: "You're already hosting #{existing.name} for this meal. " \
                       "Only one hosted spot per person per meal."
  end

  def meal_spot_params
    params.require(:meal_spot).permit(:name, :map_url, :meet_up_spot, :contact_info, :is_public)
  end

  def transport_params
    params.require(:transport).permit(:mode, :departs_at, :seats_offered)
  end

  def remove_existing_rsvp_for_meal!
    MealSpotRsvp.where(user: current_user, schedule_item: @meal).destroy_all
  end
end
