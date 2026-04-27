class HackProject < ApplicationRecord
  belongs_to :schedule_item
  belongs_to :host, class_name: "User"

  has_many :hack_project_signups, dependent: :destroy
  has_many :participants, through: :hack_project_signups, source: :user

  enum :skill_level, { beginner: 0, intermediate: 1, advanced: 2 }

  URL_FORMAT = URI::DEFAULT_PARSER.make_regexp(%w[http https])

  validates :title, :repo_url, presence: true
  validates :repo_url, format: { with: URL_FORMAT }
  validates :contributors_guide_url, format: { with: URL_FORMAT, allow_blank: true }
  validates :host_id, uniqueness: {
    scope: :schedule_item_id,
    message: "is already hosting another Hack Day project"
  }
  validate :parent_must_be_hack_day

  def editable_by?(user)
    return false if user.nil?
    user.admin? || host_id == user.id
  end

  def removable_by?(user)
    user&.admin?
  end

  def mentor_signups
    hack_project_signups.mentor
  end

  def mentee_signups
    hack_project_signups.mentee
  end

  private

  def parent_must_be_hack_day
    return if schedule_item&.hack_day?
    errors.add(:schedule_item, "must be Hack Day")
  end
end
