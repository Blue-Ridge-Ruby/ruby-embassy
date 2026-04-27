class ScheduleController < ApplicationController
  def index
    @selected_kind = ScheduleItem.kinds.key?(params[:kind].to_s) ? params[:kind] : nil
    @items_by_day  = ScheduleItem.visible_to(current_user).by_kind(@selected_kind).ordered.group_by(&:day)
    @planned_ids   = current_user.plan_items.pluck(:schedule_item_id).to_set
  end
end
