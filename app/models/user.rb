class User < ApplicationRecord
  enum :role, { attendee: 0, volunteer: 1, admin: 2 }

  has_many :plan_items, dependent: :destroy
  has_many :planned_schedule_items, through: :plan_items, source: :schedule_item
  has_many :lightning_talk_signups, dependent: :destroy
  has_many :speaking_at, through: :lightning_talk_signups, source: :schedule_item
  has_many :embassy_bookings, dependent: :destroy
  has_many :embassy_applications, through: :embassy_bookings
  has_many :meal_spot_rsvps, dependent: :destroy
  has_many :created_schedule_items,
           class_name: "ScheduleItem",
           foreign_key: :created_by_id,
           dependent: :nullify,
           inverse_of: :created_by

  before_save :memorialize_tito_config
  after_create :materialize_default_plan_items

  generates_token_for :login, expires_in: 30.days

  validates :email, presence: true, uniqueness: true
  validates :first_name, presence: true, on: :interactive
  validates :last_name, presence: true, on: :interactive

  normalizes :first_name, :last_name, :tito_ticket_slug, with: ->(v) { v.presence }
  normalizes :email, with: ->(e) { e.strip.downcase.presence }

  # Class-level readers point at the *current* event's credentials (from ENV).
  # Used for live Tito API calls (sync, login lookup).
  def self.tito_api_token    = ENV["TITO_API_TOKEN"]
  def self.tito_account_slug = ENV["TITO_ACCOUNT_SLUG"]
  def self.tito_event_slug   = ENV["TITO_EVENT_SLUG"]

  # Instance readers prefer the slugs memorialized on the row (the event that
  # issued *this* user's ticket) and fall back to the current ENV values when
  # none are stored yet.
  def tito_account_slug = attributes["tito_account_slug"].presence || self.class.tito_account_slug
  def tito_event_slug   = attributes["tito_event_slug"].presence   || self.class.tito_event_slug
  def tito_api_token    = self.class.tito_api_token

  def self.tito_client
    Tito::Admin::Client.new(
      token: tito_api_token,
      account: tito_account_slug,
      event: tito_event_slug
    )
  end

  def tito_client = self.class.tito_client

  def admin_ticket_url
    return nil if tito_ticket_slug.blank?
    "https://dashboard.tito.io/#{tito_account_slug}/#{tito_event_slug}/tickets/#{tito_ticket_slug}"
  end

  def full_name
    [ first_name, last_name ].compact.join(" ").presence || email
  end

  def speaking_at?(schedule_item)
    lightning_talk_signups.exists?(schedule_item_id: schedule_item.id)
  end

  # Idempotent: safe to call from after_create and from the backfill task.
  def materialize_default_plan_items
    ScheduleItem.default_plan.find_each do |item|
      plan_items.find_or_create_by!(schedule_item: item)
    end
  end

  private

  # When a user gets linked to a Tito ticket, snapshot the current event's
  # slugs onto the row. That way, next year's deploy (with new ENV slugs)
  # still renders correct admin_ticket_url values for this year's users.
  def memorialize_tito_config
    return if tito_ticket_slug.blank?
    self[:tito_account_slug] ||= self.class.tito_account_slug
    self[:tito_event_slug]   ||= self.class.tito_event_slug
  end
end
