class EmbassyApplicationsController < ApplicationController
  def new
    @plan_item     = current_user.plan_items.find_by(id: params[:plan_item_id])
    @schedule_item = @plan_item&.schedule_item
    @sections      = FakeEmbassy.sample_questions
    @serial        = FakeEmbassy.serial_for(@plan_item&.id || 1)
    @minutes_left  = FakeEmbassy.reservation_minutes_left(@plan_item&.id || 1)
  end

  def create
    plan_item_id = params[:plan_item_id] || 1
    redirect_to embassy_application_path(FakeEmbassy.serial_for(plan_item_id))
  end

  def show
    @serial        = params[:id]
    @sections      = FakeEmbassy.sample_questions
    @schedule_item = ScheduleItem.embassy.first || ScheduleItem.first
    @plan_item     = current_user.plan_items.joins(:schedule_item)
                                 .where(schedule_items: { kind: ScheduleItem.kinds[:embassy] })
                                 .first
  end

  def edit
    redirect_to new_embassy_application_path(plan_item_id: params[:id])
  end

  def update
    redirect_to embassy_application_path(params[:id])
  end
end
