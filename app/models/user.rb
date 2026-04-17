class User < ApplicationRecord
  include Configuration::Configurable

  configure_with :tito_account_slug, :tito_event_slug, :tito_api_token, instance_methods: false

  enum :role, { attendee: 0, volunteer: 1, admin: 2 }

  before_save :memorialize_tito_config

  generates_token_for :login, expires_in: 30.days

  validates :email, presence: true, uniqueness: true
  validates :first_name, presence: true, on: :interactive
  validates :last_name, presence: true, on: :interactive

  normalizes :first_name, :last_name, :tito_ticket_slug, with: ->(v) { v.presence }
  normalizes :email, with: ->(e) { e.strip.downcase.presence }

  def tito_event_slug   = attributes["tito_event_slug"]   || self.class.tito_event_slug
  def tito_account_slug = attributes["tito_account_slug"] || self.class.tito_account_slug
  def tito_api_token    = self.class.tito_api_token

  def self.tito_client
    Tito::Admin::Client.new(token: tito_api_token, account: tito_account_slug, event: tito_event_slug)
  end

  def tito_client
    Tito::Admin::Client.new(token: tito_api_token, account: tito_account_slug, event: tito_event_slug)
  end

  def admin_ticket_url
    tito_ticket_slug && "https://dashboard.tito.io/#{tito_account_slug}/#{tito_event_slug}/tickets/#{tito_ticket_slug}"
  end

  def full_name
    [first_name, last_name].compact.join(" ").presence || email
  end

  private

  def memorialize_tito_config
    return unless tito_ticket_slug.present?
    self.tito_account_slug = tito_account_slug
    self.tito_event_slug   = tito_event_slug
  end
end
