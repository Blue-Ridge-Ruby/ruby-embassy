module Admin
  class DashboardController < AdminController
    def show
      @user_counts          = User.group(:role).count
      @total_users          = User.count
      @total_schedule_items = ScheduleItem.count
      @public_items         = ScheduleItem.where(is_public: true).count
      @total_rsvps          = PlanItem.count
    end
  end
end
