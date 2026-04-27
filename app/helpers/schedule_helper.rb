module ScheduleHelper
  KIND_DISPLAY_OVERRIDES = { "lightning" => "⚡ Lightning Talks" }.freeze

  def kind_display_label(kind)
    return nil if kind.blank?
    KIND_DISPLAY_OVERRIDES[kind.to_s] || kind.to_s.humanize
  end

  def visible_filter_kinds(user)
    ScheduleItem.kinds.keys.reject do |kind|
      kind == "reception" ||
        (kind == "volunteer" && !(user&.volunteer? || user&.admin?))
    end.sort_by { |kind| kind_display_label(kind) }
  end

  # Visibility rule for an activity PlanItem's contact_method:
  # - the activity creator (host) always sees contacts
  # - anyone with their own PlanItem for the same activity sees the others
  def can_see_activity_contact?(viewer, plan_item)
    return false if viewer.nil? || plan_item.nil?
    return true  if plan_item.user_id == viewer.id
    item = plan_item.schedule_item
    return true  if item.created_by_id == viewer.id
    viewer.plan_items.exists?(schedule_item_id: plan_item.schedule_item_id)
  end
end
