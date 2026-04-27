class NotaryProfile < ApplicationRecord
  has_many :embassy_applications, dependent: :nullify

  enum :status, { active: "active", archived: "archived" }

  validates :external_id, presence: true, uniqueness: true
  validates :description, presence: true

  def usage_count
    embassy_applications.where(state: "submitted").count
  end

  def self.next_external_id
    numbers = pluck(:external_id).filter_map { |id| id.match(/\AN(\d+)\z/)&.[](1)&.to_i }
    "N%02d" % ((numbers.max || 0) + 1)
  end
end
