class ScheduleItemsController < ApplicationController
  before_action :set_schedule_item, only: %i[edit update]

  def new
    @schedule_item = current_user.created_schedule_items.build(
      day: params[:day] || "sat",
      flexible: false,
      is_public: false
    )
  end

  def create
    @schedule_item = current_user.created_schedule_items.build(
      schedule_item_params.merge(kind: :activity)
    )

    if @schedule_item.save
      redirect_to plan_path, notice: "Item added to your plan."
    else
      render :new, status: :unprocessable_content
    end
  end

  def edit
  end

  def update
    if @schedule_item.update(schedule_item_params)
      redirect_to plan_path, notice: "Item updated."
    else
      render :edit, status: :unprocessable_content
    end
  end

  private

  def set_schedule_item
    @schedule_item = current_user.created_schedule_items.find(params[:id])
  end

  # :kind and :created_by_id are deliberately absent here — the controller
  # hardcodes kind: :activity on create, never changes it on update, and
  # always scopes to current_user.created_schedule_items.
  def schedule_item_params
    params.require(:schedule_item).permit(
      :day, :time_label, :sort_time, :title, :host,
      :location, :description, :flexible, :is_public
    )
  end
end
