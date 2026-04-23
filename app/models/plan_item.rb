class PlanItem < ApplicationRecord
  belongs_to :user
  belongs_to :schedule_item

  validates :user_id, uniqueness: {
    scope: :schedule_item_id,
    message: "already has this item on their plan"
  }
end
