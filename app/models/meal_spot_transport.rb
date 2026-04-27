class MealSpotTransport < ApplicationRecord
  belongs_to :meal_spot
  has_one :schedule_item, through: :meal_spot

  has_many :rsvps, class_name: "MealSpotRsvp", dependent: :destroy
  has_many :users, through: :rsvps

  enum :mode, { walking: 0, driving: 1 }

  validates :mode,       presence: true,
                         uniqueness: { scope: :meal_spot_id }
  validates :departs_at, presence: true
  validates :seats_offered,
            presence: true,
            numericality: { only_integer: true, greater_than_or_equal_to: 0 },
            if: :driving?

  MODE_LABELS = { "walking" => "Walking", "driving" => "Driving" }.freeze

  def mode_label
    MODE_LABELS[mode] || mode.to_s.humanize
  end

  # Passenger seats already taken (everyone except the driver). The driver
  # is the first person who RSVPd — they implicitly hold their own seat,
  # which isn't counted in `seats_offered`.
  def passenger_count
    [ rsvps.count - 1, 0 ].max
  end

  def seats_remaining
    return nil unless driving?
    [ seats_offered.to_i - passenger_count, 0 ].max
  end

  def full?
    driving? && seats_remaining.zero?
  end

  # The first person to RSVP to this transport — implicitly its organizer.
  # For driving transports, that's the driver.
  def organizer
    rsvps.min_by(&:created_at)&.user
  end

  def started_by?(user)
    return false if user.nil?
    organizer&.id == user.id
  end
end
