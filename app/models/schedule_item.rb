class ScheduleItem < ApplicationRecord
  belongs_to :created_by, class_name: "User", optional: true
  has_many :plan_items, dependent: :destroy
  has_many :attendees, through: :plan_items, source: :user

  enum :kind, { talk: 0, lightning: 1, embassy: 2, activity: 3 }

  validates :title, presence: true
  validates :day,   presence: true
  validates :kind,  presence: true

  DAY_META = {
    "wed" => { label: "Wednesday", date: "April 29", subtitle: "Pre-Conference" },
    "thu" => { label: "Thursday",  date: "April 30", subtitle: "Conference Day 1" },
    "fri" => { label: "Friday",    date: "May 1",    subtitle: "Conference Day 2" },
    "sat" => { label: "Saturday",  date: "May 2",    subtitle: "Activities & Ruby Embassy" }
  }.freeze

  scope :public_items, -> { where(is_public: true) }
  scope :ordered, -> {
    order(
      Arel.sql("CASE day WHEN 'wed' THEN 1 WHEN 'thu' THEN 2 WHEN 'fri' THEN 3 WHEN 'sat' THEN 4 ELSE 5 END"),
      :sort_time
    )
  }

  # Creators always get auto-added to their own plan — whether the item is
  # private (only they see it) or public (others can RSVP). The rationale:
  # if you propose a group hike, you're obviously going to it.
  after_create :auto_plan_for_creator, if: -> { created_by_id.present? }

  def rsvp_count
    plan_items.count
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
