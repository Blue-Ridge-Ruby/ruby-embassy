class MealSpot < ApplicationRecord
  belongs_to :schedule_item
  belongs_to :created_by, class_name: "User", optional: true

  has_many :transports, class_name: "MealSpotTransport", dependent: :destroy
  has_many :rsvps, through: :transports
  has_many :attendees, through: :rsvps, source: :user

  validates :name, presence: true,
                   uniqueness: { scope: :schedule_item_id, case_sensitive: false }
  validate  :parent_must_be_meal

  # Lazily creates (or finds) the single canonical spot for a hosted meal.
  # The spot mirrors the meal's location so all transports for a hosted
  # meal attach to one spot — attendees never suggest alternates.
  def self.canonical_for_hosted!(meal)
    name = meal.location.presence || meal.host
    find_or_create_by!(schedule_item: meal, name: name) do |spot|
      spot.map_url     = meal.map_url.presence || meal.host_url
      spot.created_by  = nil
      spot.is_public   = true
    end
  end

  # The auto-created spot for a hosted meal. Identified by nil creator —
  # users can never create a spot without a creator, so this is unambiguous.
  def canonical_for_hosted?
    created_by_id.nil? && schedule_item.hosted?
  end

  def rsvp_count
    rsvps.count
  end

  # Creator can edit only when no one else has RSVPd. Once a second person
  # commits, edits are admin-only — protects joiners from rug-pulls. The
  # canonical hosted spot has no creator, so it's admin-only edit territory
  # (and admins should edit the meal itself, not the spot).
  def editable_by?(user)
    return false if user.nil?
    return true  if user.admin?
    return false if created_by_id.nil?
    return false unless created_by_id == user.id
    rsvps.where.not(user_id: created_by_id).none?
  end

  # Called from MealSpotRsvp#after_destroy. If the creator just removed
  # their own RSVP, hand the spot to whoever's been there longest. Skipped
  # for canonical hosted spots — those stay creatorless by design.
  def transfer_ownership_if_creator_left!
    return if created_by_id.nil?
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
