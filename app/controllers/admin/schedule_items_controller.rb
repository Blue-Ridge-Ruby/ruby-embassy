module Admin
  class ScheduleItemsController < AdminController
    before_action :set_schedule_item, only: %i[edit update destroy]

    def index
      @schedule_items = ScheduleItem.ordered
    end

    def new
      @schedule_item = ScheduleItem.new(day: "fri", kind: :talk, is_public: true, flexible: false)
    end

    def create
      @schedule_item = ScheduleItem.new(schedule_item_params)
      if @schedule_item.save
        redirect_to admin_schedule_items_path, notice: "Schedule item created."
      else
        render :new, status: :unprocessable_content
      end
    end

    def edit
    end

    def update
      if @schedule_item.update(schedule_item_params)
        redirect_to admin_schedule_items_path, notice: "Schedule item updated."
      else
        render :edit, status: :unprocessable_content
      end
    end

    def destroy
      @schedule_item.destroy
      redirect_to admin_schedule_items_path, notice: "Schedule item deleted."
    end

    private

    def set_schedule_item
      @schedule_item = ScheduleItem.find(params[:id])
    end

    # Admins can freely set :kind, unlike user-facing controller.
    # :slug is intentionally omitted — it's a seed idempotency key for
    # config/schedule.yml items and should never be set by hand.
    def schedule_item_params
      params.require(:schedule_item).permit(
        :day, :time_label, :sort_time, :title, :host,
        :location, :description, :kind, :flexible, :is_public
      )
    end
  end
end
