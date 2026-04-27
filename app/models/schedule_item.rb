class ScheduleItem < ApplicationRecord
  EMBASSY_MODES = %w[new_passport stamping passport_pickup].freeze
  DEFAULT_PLAN_KINDS = %w[talk reception].freeze

  belongs_to :created_by, class_name: "User", optional: true
  has_many :plan_items, dependent: :destroy
  has_many :attendees, through: :plan_items, source: :user
  has_many :lightning_talk_signups, -> { ordered }, dependent: :destroy
  has_many :speakers, through: :lightning_talk_signups, source: :user
  has_many :embassy_bookings, dependent: :destroy
  has_many :meal_spots, dependent: :destroy

  enum :kind, {
    talk: 0, lightning: 1, embassy: 2, activity: 3,
    reception: 4, meal: 5, community: 6, volunteer: 7
  }

  enum :audience, { everyone: "everyone", volunteers_only: "volunteers_only" }, prefix: :audience

  validates :title, presence: true
  validates :day,   presence: true
  validates :kind,  presence: true
  validates :new_passport_capacity,    numericality: { only_integer: true, greater_than: 0 }, allow_nil: true
  validates :stamping_capacity,        numericality: { only_integer: true, greater_than: 0 }, allow_nil: true
  validates :passport_pickup_capacity, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true
  validates :volunteer_capacity, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true
  validates :volunteer_capacity, presence: true, if: :volunteer?
  validate  :at_least_one_embassy_mode_selected, if: :embassy?
  validate  :capacity_present_for_offered_modes, if: :embassy?

  DAY_META = {
    "wed" => { label: "Wednesday", date: "April 29", subtitle: "Pre-Conference" },
    "thu" => { label: "Thursday",  date: "April 30", subtitle: "Conference Day 1" },
    "fri" => { label: "Friday",    date: "May 1",    subtitle: "Conference Day 2" },
    "sat" => { label: "Saturday",  date: "May 2",    subtitle: "Activities & Ruby Embassy" },
    "sun" => { label: "Sunday",    date: "May 3",    subtitle: "Departures" }
  }.freeze

  scope :public_items, -> { where(is_public: true) }
  # Public items filtered to what `user` is allowed to see. Admins and
  # volunteers see all public items; everyone else (attendees, signed-out)
  # sees only items with audience: "everyone".
  scope :visible_to, ->(user) {
    return public_items if user&.admin? || user&.volunteer?
    public_items.where(audience: "everyone")
  }
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
  # Junk-safe: returns all rows when day is blank or unknown.
  scope :by_day, ->(day) {
    day.present? && DAY_META.key?(day.to_s) ? where(day: day) : all
  }
  scope :volunteer_empty, -> { volunteer.where.missing(:plan_items) }
  # Items every attendee is auto-RSVPed to on signup (and via the backfill
  # task). Restricted to public, audience: "everyone" so volunteer-only items
  # are never auto-added to attendees' plans.
  scope :default_plan, -> {
    public_items.where(audience: "everyone", kind: kinds.values_at(*DEFAULT_PLAN_KINDS))
  }

  # Creators always get auto-added to their own plan — whether the item is
  # private (only they see it) or public (others can RSVP). The rationale:
  # if you propose a group hike, you're obviously going to it.
  after_create :auto_plan_for_creator, if: -> { created_by_id.present? }

  def rsvp_count
    plan_items.count
  end

  def hosted?
    meal? && host.present?
  end

  def seats_taken_for(mode)
    embassy_bookings.active.where(mode: mode).count
  end

  def capacity_for(mode)
    public_send("#{mode}_capacity")
  end

  def offers?(mode)
    public_send("offers_#{mode}?")
  end

  def seats_remaining_for(mode)
    cap = capacity_for(mode)
    return nil unless cap
    [ cap - seats_taken_for(mode), 0 ].max
  end

  def full_for?(mode)
    cap = capacity_for(mode)
    cap.present? && seats_remaining_for(mode).zero?
  end

  def active_embassy_modes
    EMBASSY_MODES.select { |m| offers?(m) }
  end

  def lightning_slots_full?
    lightning? && lightning_talk_signups.count >= LightningTalkSignup::MAX_SPEAKERS
  end

  def seats_taken_for(mode)
    embassy_bookings.active.where(mode: mode).count
  end

  def capacity_for(mode)
    public_send("#{mode}_capacity")
  end

  def offers?(mode)
    public_send("offers_#{mode}?")
  end

  def seats_remaining_for(mode)
    cap = capacity_for(mode)
    return nil unless cap
    [ cap - seats_taken_for(mode), 0 ].max
  end

  def full_for?(mode)
    cap = capacity_for(mode)
    cap.present? && seats_remaining_for(mode).zero?
  end

  def active_embassy_modes
    EMBASSY_MODES.select { |m| offers?(m) }
  end

  def seats_taken
    embassy_bookings.active.count
  end

  def total_capacity
    EMBASSY_MODES.sum { |m| capacity_for(m) || 0 }
  end

  def seats_remaining
    return nil unless total_capacity.positive?
    [ total_capacity - seats_taken, 0 ].max
  end

  def full?
    return false unless embassy?
    modes = active_embassy_modes
    modes.any? && modes.all? { |m| full_for?(m) }
  end

  # Derived for compatibility with views that read embassy_mode directly.
  # Pickup is intentionally excluded from "both" — callers needing pickup
  # info should use offers_passport_pickup? directly.
  def embassy_mode
    return "both"            if offers_new_passport? && offers_stamping?
    return "new_passport"    if offers_new_passport?
    return "stamping"        if offers_stamping?
    return "passport_pickup" if offers_passport_pickup?
    nil
  end

  def volunteer_signup_count
    plan_items.count
  end

  def volunteer_seats_remaining
    return nil unless volunteer_capacity
    [ volunteer_capacity - volunteer_signup_count, 0 ].max
  end

  def volunteer_empty?
    volunteer? && volunteer_signup_count.zero?
  end

  def volunteer_full?
    volunteer? && volunteer_capacity.present? && volunteer_seats_remaining.zero?
  end

  def volunteer_partial?
    volunteer? && !volunteer_empty? && !volunteer_full?
  end

  def volunteer_state
    return nil unless volunteer?
    return :empty if volunteer_empty?
    return :full  if volunteer_full?
    :partial
  end

  def editable_by?(user)
    return false if user.nil?
    user.admin? || created_by_id == user.id
  end

  private

  def auto_plan_for_creator
    plan_items.create!(user: created_by)
  end

  def at_least_one_embassy_mode_selected
    return if active_embassy_modes.any?
    errors.add(:base, "Embassy block must offer at least one mode (new passport, stamping, or pickup).")
  end

  def capacity_present_for_offered_modes
    EMBASSY_MODES.each do |mode|
      next unless offers?(mode)
      next if capacity_for(mode).to_i.positive?
      errors.add(:"#{mode}_capacity", "must be set when this mode is offered")
    end
  end
end
