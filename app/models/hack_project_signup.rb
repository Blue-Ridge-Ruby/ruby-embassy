class HackProjectSignup < ApplicationRecord
  belongs_to :user
  belongs_to :hack_project
  belongs_to :schedule_item

  enum :role, { mentor: 0, mentee: 1 }

  validates :user_id, uniqueness: {
    scope: :schedule_item_id,
    message: "is already on a Hack Day project"
  }

  before_validation :inherit_schedule_item_from_project
  after_create  :ensure_parent_plan_item
  after_save    :sync_plan_item_role

  private

  def inherit_schedule_item_from_project
    self.schedule_item_id ||= hack_project&.schedule_item_id
  end

  def ensure_parent_plan_item
    PlanItem.find_or_create_by!(user_id: user_id, schedule_item_id: schedule_item_id)
  end

  def sync_plan_item_role
    PlanItem.where(user_id: user_id, schedule_item_id: schedule_item_id)
            .update_all(hack_role: HackProjectSignup.roles[role])
  end
end
