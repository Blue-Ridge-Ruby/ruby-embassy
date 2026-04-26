class ScheduleItem < ApplicationRecord
  EMBASSY_MODES = %w[new_passport stamping both].freeze

  belongs_to :created_by, class_name: "User", optional: true
  has_many :plan_items, dependent: :destroy
  has_many :attendees, through: :plan_items, source: :user
  has_many :embassy_bookings, dependent: :destroy

  enum :kind, { talk: 0, lightning: 1, embassy: 2, activity: 3 }

  validates :title, presence: true
  validates :day,   presence: true
  validates :kind,  presence: true
  validates :embassy_mode, inclusion: { in: EMBASSY_MODES }, allow_nil: true
  validates :embassy_capacity, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true

  DAY_META = {
    "wed" => { label: "Wednesday", date: "April 29", subtitle: "Pre-Conference" },
    "thu" => { label: "Thursday",  date: "April 30", subtitle: "Conference Day 1" },
    "fri" => { label: "Friday",    date: "May 1",    subtitle: "Conference Day 2" },
    "sat" => { label: "Saturday",  date: "May 2",    subtitle: "Activities & Ruby Embassy" },
    "sun" => { label: "Sunday",    date: "May 3",    subtitle: "Departures" }
  }.freeze

  scope :public_items, -> { where(is_public: true) }
  scope :ordered, -> {
    order(
      Arel.sql(
        "CASE day " \
          "WHEN 'wed' THEN 1 " \
          "WHEN 'thu' THEN 2 " \
          "WHEN 'fri' THEN 3 " \
          "WHEN 'sat' THEN 4 " \
          "WHEN 'sun' THEN 5 " \
          "ELSE 6 END"
      ),
      :sort_time
    )
  }
  # Junk-safe: returns all rows when kind is blank or unknown.
  scope :by_kind, ->(kind) {
    kind.present? && kinds.key?(kind.to_s) ? where(kind: kind) : all
  }

  # Creators always get auto-added to their own plan — whether the item is
  # private (only they see it) or public (others can RSVP). The rationale:
  # if you propose a group hike, you're obviously going to it.
  after_create :auto_plan_for_creator, if: -> { created_by_id.present? }

  def rsvp_count
    plan_items.count
  end

  def seats_taken
    embassy_bookings.active.count
  end

  def seats_remaining
    return nil unless embassy_capacity
    [ embassy_capacity - seats_taken, 0 ].max
  end

  def full?
    embassy_capacity.present? && seats_remaining.zero?
  end

  def editable_by?(user)
    return false if user.nil?
    user.admin? || created_by_id == user.id
  end

  private

  def auto_plan_for_creator
    plan_items.create!(user: created_by)
  end
end
