module Admin
  class DashboardController < AdminController
    def show
      @attendees_count            = User.attendee.count
      @embassy_applications_count = EmbassyApplication.submitted.where(passport_received_at: nil).count
      @rsvps_count                = PlanItem.count
      @hosted_activities_count    = ScheduleItem.activity.count
      @public_items_count         = ScheduleItem.where(is_public: true).count
    end
  end
end
