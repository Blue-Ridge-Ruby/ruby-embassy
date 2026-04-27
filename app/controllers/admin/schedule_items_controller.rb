module Admin
  class ScheduleItemsController < AdminController
    before_action :set_schedule_item, only: %i[edit update destroy]

    def index
      # Filters persist in the admin's session so they survive redirects after
      # edit/update/delete and "back from another page" navigation. An explicit
      # blank param (sent by the "All" pill) clears that session slot.
      if params.key?(:kind)
        @selected_kind = ScheduleItem.kinds.key?(params[:kind].to_s) ? params[:kind] : nil
        session[:admin_schedule_kind] = @selected_kind
      else
        @selected_kind = session[:admin_schedule_kind]
      end

      if params.key?(:day)
        @selected_day = ScheduleItem::DAY_META.key?(params[:day].to_s) ? params[:day] : nil
        session[:admin_schedule_day] = @selected_day
      else
        @selected_day = session[:admin_schedule_day]
      end

      @schedule_items = ScheduleItem.by_kind(@selected_kind).by_day(@selected_day).ordered
    end

    def new
      requested_kind = ScheduleItem.kinds.key?(params[:kind].to_s) ? params[:kind] : :talk
      @schedule_item = ScheduleItem.new(day: "fri", kind: requested_kind, is_public: true, flexible: false)
    end

    def create
      @schedule_item = ScheduleItem.new(schedule_item_params)
      if @schedule_item.save
        redirect_to safe_return_to || admin_schedule_items_path, notice: "Schedule item created."
      else
        render :new, status: :unprocessable_content
      end
    end

    def edit
    end

    def update
      if @schedule_item.update(schedule_item_params)
        redirect_to safe_return_to || admin_schedule_items_path, notice: "Schedule item updated."
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

    def safe_return_to
      raw = params[:return_to].to_s
      raw if raw.start_with?("/") && !raw.start_with?("//")
    end

    # Admins can freely set :kind, unlike user-facing controller.
    # :slug is intentionally omitted — it's a seed idempotency key for
    # config/schedule.yml items and should never be set by hand.
    def schedule_item_params
      attrs = params.require(:schedule_item).permit(
        :day, :time_label, :sort_time, :title, :host,
        :location, :map_url, :description, :kind, :flexible, :is_public, :audience,
        :offers_new_passport, :offers_stamping, :offers_passport_pickup,
        :new_passport_capacity, :stamping_capacity, :passport_pickup_capacity,
        :volunteer_capacity
      )
      if attrs[:kind] == "embassy"
        ScheduleItem::EMBASSY_MODES.each do |mode|
          attrs[:"#{mode}_capacity"] = nil unless ActiveModel::Type::Boolean.new.cast(attrs[:"offers_#{mode}"])
        end
      else
        attrs[:offers_new_passport]      = false
        attrs[:offers_stamping]          = false
        attrs[:offers_passport_pickup]   = false
        attrs[:new_passport_capacity]    = nil
        attrs[:stamping_capacity]        = nil
        attrs[:passport_pickup_capacity] = nil
      end
      attrs[:volunteer_capacity] = nil unless attrs[:kind] == "volunteer"
      attrs
    end
  end
end
