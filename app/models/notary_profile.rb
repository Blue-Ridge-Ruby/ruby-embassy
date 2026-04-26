class NotaryProfile < ApplicationRecord
  has_many :embassy_applications, dependent: :nullify

  enum :status, { active: "active", archived: "archived" }

  validates :external_id, presence: true, uniqueness: true
  validates :description, presence: true

  def usage_count
    embassy_applications.where(state: "submitted").count
  end
end
