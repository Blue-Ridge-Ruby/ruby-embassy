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
      schedule_item_params.merge(auto_attrs)
    )

    if @schedule_item.save
      day_key    = @schedule_item.day
      plan_items = current_user.plan_items.includes(:schedule_item).for_day(day_key)

      respond_to do |format|
        format.turbo_stream {
          render turbo_stream: [
            # Replace the day's plan_items container — the new custom block
            # slots in; the "Nothing planned yet" placeholder disappears.
            turbo_stream.replace(
              "plan_items_#{day_key}",
              partial: "plan/items_for_day",
              locals: { day_key: day_key, plan_items: plan_items }
            ),
            # Collapse the form back to the "+ Add custom block" link.
            turbo_stream.replace(
              "new_schedule_item_#{day_key}",
              partial: "schedule_items/new_link",
              locals: { day_key: day_key }
            )
          ]
        }
        format.html { redirect_to plan_path, notice: "Item added to your plan." }
      end
    else
      render :new, status: :unprocessable_content
    end
  end

  def edit
  end

  def update
    if @schedule_item.update(schedule_item_params.merge(auto_attrs))
      redirect_to plan_path, notice: "Item updated."
    else
      render :edit, status: :unprocessable_content
    end
  end

  private

  def set_schedule_item
    @schedule_item = current_user.created_schedule_items.find(params[:id])
  end

  # Permitted user-settable fields. Deliberately absent:
  #   :kind          — forced to :activity in auto_attrs
  #   :host          — forced to current_user.full_name in auto_attrs
  #   :sort_time     — derived from :time_label in auto_attrs
  #   :created_by_id — forced by association scope (current_user.created_schedule_items)
  def schedule_item_params
    params.require(:schedule_item).permit(
      :day, :time_label, :title, :location, :description, :flexible, :is_public
    )
  end

  def auto_attrs
    {
      kind:      :activity,
      host:      current_user.full_name,
      sort_time: derive_sort_time(params.dig(:schedule_item, :time_label))
    }
  end

  # "6:30 PM" -> 1830, "8:00 AM" -> 800, "whenever" -> 0.
  def derive_sort_time(time_label)
    return 0 if time_label.blank?
    parsed = Time.parse(time_label) rescue nil
    parsed ? (parsed.hour * 100 + parsed.min) : 0
  end
end
