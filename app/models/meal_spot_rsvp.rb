class MealSpotRsvp < ApplicationRecord
  belongs_to :user
  belongs_to :meal_spot_transport
  belongs_to :schedule_item

  has_one :meal_spot, through: :meal_spot_transport

  validates :user_id, uniqueness: {
    scope: :schedule_item_id,
    message: "is already going to a spot for this meal"
  }
  validate :car_must_have_seat_left, on: :create

  before_validation :inherit_schedule_item_from_transport
  after_create  :ensure_parent_plan_item
  after_destroy :transfer_spot_ownership

  private

  # Denormalize so the (user_id, schedule_item_id) unique index can enforce
  # "one spot per user per meal event" without a trigger.
  def inherit_schedule_item_from_transport
    return if schedule_item_id.present?
    self.schedule_item_id = meal_spot_transport&.meal_spot&.schedule_item_id
  end

  # Decision B from the interview: joining a spot also marks you "going"
  # for the parent meal so the plan view stays consistent.
  def ensure_parent_plan_item
    PlanItem.find_or_create_by!(user_id: user_id, schedule_item_id: schedule_item_id)
  end

  def transfer_spot_ownership
    meal_spot_transport.meal_spot&.transfer_ownership_if_creator_left!
  end

  # Driving transports cap how many passengers can join. The first RSVP is
  # the driver and is always allowed (they're the one offering the ride).
  def car_must_have_seat_left
    return unless meal_spot_transport&.driving?
    return if meal_spot_transport.rsvps.empty? # this row will become the driver
    return unless meal_spot_transport.full?
    errors.add(:base, "this car is already full")
  end
end
