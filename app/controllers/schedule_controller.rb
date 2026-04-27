class ScheduleController < ApplicationController
  def index
    @selected_kind  = ScheduleItem.kinds.key?(params[:kind].to_s) ? params[:kind] : nil
    @show_unplanned = params[:unplanned].present?
    @planned_ids    = current_user.plan_items.pluck(:schedule_item_id).to_set

    scope = ScheduleItem.visible_to(current_user).by_kind(@selected_kind).ordered
    scope = scope.where.not(id: @planned_ids) if @show_unplanned

    @items_by_day = scope.group_by(&:day)
  end
end
