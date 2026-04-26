class Question < ApplicationRecord
  has_many :embassy_application_answers, dependent: :restrict_with_error

  enum :field_type, {
    short: "short", long: "long", select: "select",
    checkbox: "checkbox", checkbox_group: "checkbox_group", date: "date"
  }, prefix: :field_type
  enum :scope,  { common: "common", random_pool: "random_pool" }
  enum :status, { active: "active", archived: "archived" }

  validates :external_id, presence: true, uniqueness: true
  validates :section, :label, :field_type, :scope, :status, presence: true

  scope :for_section, ->(n) { where(section: n).order(:position) }
  scope :random_pool_active, -> { random_pool.active }
  scope :ordered, -> { order(:section, :position) }

  def usage_count
    embassy_application_answers
      .joins(:embassy_application)
      .where(embassy_applications: { state: "submitted" })
      .distinct.count(:embassy_application_id)
  end
end
