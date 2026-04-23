class PlanItemsController < ApplicationController
  before_action :set_plan_item, only: %i[update destroy]

  def create
    schedule_item = ScheduleItem.find(params[:schedule_item_id])
    @plan_item = current_user.plan_items.find_or_create_by(schedule_item: schedule_item)

    respond_to do |format|
      format.turbo_stream {
        render turbo_stream: turbo_stream.replace(
          helpers.dom_id(schedule_item),
          partial: "schedule/session_item",
          locals: { item: schedule_item, planned: true }
        )
      }
      format.html { redirect_back fallback_location: schedule_path }
    end
  end

  def update
    @plan_item.update(plan_item_params)
    respond_to do |format|
      format.turbo_stream {
        render turbo_stream: turbo_stream.replace(
          helpers.dom_id(@plan_item),
          partial: "plan/plan_item",
          locals: { plan_item: @plan_item }
        )
      }
      format.html { redirect_to plan_path }
    end
  end

  def destroy
    schedule_item = @plan_item.schedule_item
    @plan_item.destroy

    respond_to do |format|
      format.turbo_stream {
        render turbo_stream: turbo_stream.replace(
          helpers.dom_id(schedule_item),
          partial: "schedule/session_item",
          locals: { item: schedule_item, planned: false }
        )
      }
      format.html { redirect_back fallback_location: plan_path }
    end
  end

  private

  def set_plan_item
    @plan_item = current_user.plan_items.find(params[:id])
  end

  def plan_item_params
    params.require(:plan_item).permit(:notes)
  end
end
