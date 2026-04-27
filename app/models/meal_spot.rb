class MealSpot < ApplicationRecord
  belongs_to :schedule_item
  belongs_to :created_by, class_name: "User"

  has_many :transports, class_name: "MealSpotTransport", dependent: :destroy
  has_many :rsvps, through: :transports
  has_many :attendees, through: :rsvps, source: :user

  validates :name, presence: true,
                   uniqueness: { scope: :schedule_item_id, case_sensitive: false }
  validate  :parent_must_be_meal

  def rsvp_count
    rsvps.count
  end

  # Creator can edit only when no one else has RSVPd. Once a second person
  # commits, edits are admin-only — protects joiners from rug-pulls.
  def editable_by?(user)
    return false if user.nil?
    return true  if user.admin?
    return false unless created_by_id == user.id
    rsvps.where.not(user_id: created_by_id).none?
  end

  # Called from MealSpotRsvp#after_destroy. If the creator just removed
  # their own RSVP, hand the spot to whoever's been there longest.
  def transfer_ownership_if_creator_left!
    return if rsvps.exists?(user_id: created_by_id)
    next_owner = rsvps.order(:created_at).first&.user
    update_columns(created_by_id: next_owner.id) if next_owner
  end

  private

  def parent_must_be_meal
    return if schedule_item&.meal?
    errors.add(:schedule_item, "must be a meal event")
  end
end
