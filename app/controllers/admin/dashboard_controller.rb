module Admin
  class DashboardController < AdminController
    def show
      @attendees_count            = User.attendee.count
      @embassy_applications_count = EmbassyApplication.submitted.where(passport_received_at: nil).count
      @rsvps_count                = PlanItem.count
      @schedule_items_count       = ScheduleItem.count
      @schedule_items_breakdown   = ScheduleItem.group(:kind).count
    end
  end
end
