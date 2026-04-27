class PlanItem < ApplicationRecord
  belongs_to :user
  belongs_to :schedule_item
  has_one :embassy_booking, dependent: :destroy

  enum :hack_role, { mentor: 0, mentee: 1 }, prefix: true

  validates :user_id, uniqueness: {
    scope: :schedule_item_id,
    message: "already has this item on their plan"
  }
  validate :volunteer_slot_not_full, on: :create

  scope :for_day, ->(day_key) {
    joins(:schedule_item)
      .where(schedule_items: { day: day_key })
      .order("schedule_items.sort_time")
  }

  private

  def volunteer_slot_not_full
    return unless schedule_item&.volunteer?
    return unless schedule_item.volunteer_full?
    errors.add(:base, "This volunteer slot is full")
  end
end
