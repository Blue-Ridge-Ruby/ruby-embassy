class LightningTalkSignup < ApplicationRecord
  MAX_SPEAKERS = 10
  BLOCK_DURATION_MINUTES = 60

  class SlotsFull < StandardError; end

  belongs_to :user
  belongs_to :schedule_item

  scope :ordered, -> { order(:position) }

  validates :user_id, uniqueness: { scope: :schedule_item_id }
  validate :schedule_item_must_be_lightning
  validate :slot_must_be_available, on: :create

  after_create_commit :ensure_plan_item

  def self.claim_next_slot!(user:, schedule_item:)
    schedule_item.with_lock do
      raise SlotsFull if schedule_item.lightning_talk_signups.count >= MAX_SPEAKERS

      next_position = (schedule_item.lightning_talk_signups.maximum(:position) || 0) + 1
      create!(user: user, schedule_item: schedule_item, position: next_position)
    end
  end

  def editable_by?(actor)
    return false if actor.nil?
    actor.admin? || actor.id == user_id
  end

  def slot_minutes
    BLOCK_DURATION_MINUTES.to_f / [ schedule_item.lightning_talk_signups.count, 1 ].max
  end

  def slot_start_label
    return schedule_item.time_label if schedule_item.sort_time.blank?

    base   = (schedule_item.sort_time / 100) * 60 + (schedule_item.sort_time % 100)
    offset = ((position - 1) * slot_minutes).round
    total  = base + offset
    Time.new(2000, 1, 1, (total / 60) % 24, total % 60).strftime("%-l:%M %p")
  end

  private

  def schedule_item_must_be_lightning
    errors.add(:schedule_item, "must be a lightning talk") unless schedule_item&.lightning?
  end

  def slot_must_be_available
    return unless schedule_item&.lightning?
    if schedule_item.lightning_talk_signups.count >= MAX_SPEAKERS
      errors.add(:base, "All speaking slots are full")
    end
  end

  def ensure_plan_item
    PlanItem.find_or_create_by!(user: user, schedule_item: schedule_item)
  end
end
