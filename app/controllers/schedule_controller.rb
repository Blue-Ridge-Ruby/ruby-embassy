class ScheduleController < ApplicationController
  def index
    @items_by_day = ScheduleItem.public_items.ordered.group_by(&:day)
    @planned_ids  = current_user.plan_items.pluck(:schedule_item_id).to_set
  end
end
