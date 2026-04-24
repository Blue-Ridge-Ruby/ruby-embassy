class PlanItem < ApplicationRecord
  belongs_to :user
  belongs_to :schedule_item

  validates :user_id, uniqueness: {
    scope: :schedule_item_id,
    message: "already has this item on their plan"
  }

  scope :for_day, ->(day_key) {
    joins(:schedule_item)
      .where(schedule_items: { day: day_key })
      .order("schedule_items.sort_time")
  }
end
