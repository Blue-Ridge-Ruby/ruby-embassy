class PlanItemsController < ApplicationController
  before_action :set_plan_item, only: %i[update destroy]

  def create
    schedule_item = ScheduleItem.visible_to(current_user).find(params[:schedule_item_id])
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
    if @plan_item.embassy_booking&.embassy_application&.submitted?
      message = "Submitted embassy applications can't be cancelled here."
      respond_to do |format|
        format.turbo_stream do
          flash.now[:alert] = message
          render turbo_stream: turbo_stream.replace(
            helpers.dom_id(@plan_item),
            partial: "plan/plan_item",
            locals: { plan_item: @plan_item }
          ), status: :forbidden
        end
        format.html { redirect_to plan_path, alert: message }
      end
      return
    end

    schedule_item    = @plan_item.schedule_item
    plan_item_dom_id = helpers.dom_id(@plan_item)

    if schedule_item.embassy?
      booking = current_user.embassy_bookings.find_by(schedule_item: schedule_item)
      if booking&.passport_pickup?
        respond_to do |format|
          format.turbo_stream { head :forbidden }
          format.html {
            redirect_back fallback_location: plan_path,
                          alert: "Passport pickup appointments are scheduled by an Embassy Attaché and can't be cancelled here."
          }
        end
        return
      end
    end

    @plan_item.destroy

    respond_to do |format|
      format.turbo_stream {
        # Emit both actions. Turbo applies stream actions globally; targets
        # that don't exist in the current DOM are silent no-ops. So this
        # single response handles both pages:
        #   - on /plan, the plan_item frame is removed (row disappears)
        #   - on /schedule, the session_item frame is swapped back to the
        #     "+ Add to plan" / "+ RSVP" state with updated count
        render turbo_stream: [
          turbo_stream.remove(plan_item_dom_id),
          turbo_stream.replace(
            helpers.dom_id(schedule_item),
            partial: "schedule/session_item",
            locals: { item: schedule_item, planned: false }
          )
        ]
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
