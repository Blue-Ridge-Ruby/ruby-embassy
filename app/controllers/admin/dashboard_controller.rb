module Admin
  class DashboardController < AdminController
    def show
      @attendees_count            = User.attendee.count
      @embassy_applications_count = EmbassyApplication.submitted.where(passport_received_at: nil).count
      @rsvps_count                = PlanItem.count
      @schedule_items_count       = ScheduleItem.count
    end
  end
end
