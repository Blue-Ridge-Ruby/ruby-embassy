class EmbassyBooking < ApplicationRecord
  belongs_to :user
  belongs_to :schedule_item
  belongs_to :plan_item
  has_one :embassy_application, dependent: :destroy

  enum :mode,  { new_passport: "new_passport", stamping: "stamping" }
  enum :state, { confirmed: "confirmed", cancelled: "cancelled" }

  validates :mode, presence: true
  validates :user_id, uniqueness: { scope: :schedule_item_id }

  scope :active, -> { confirmed }

  def application_required?
    new_passport?
  end
end
