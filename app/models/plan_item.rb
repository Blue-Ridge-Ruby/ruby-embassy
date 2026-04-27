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
  before_validation :inherit_user_contact_method, on: :create

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

  # New plan_items auto-pick up whatever contact the user last published, so
  # the host and co-RSVPers can see how to reach them right away.
  def inherit_user_contact_method
    return if contact_method.present?
    self.contact_method = user&.last_rsvp_contact_method
  end
end
