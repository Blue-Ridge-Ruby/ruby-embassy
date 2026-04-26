module Admin
  class DashboardController < AdminController
    def show
      @attendees_count            = User.attendee.count
      @embassy_applications_count = FakeEmbassy.submitted_applications.count
      @rsvps_count                = PlanItem.count
      @hosted_activities_count    = ScheduleItem.activity.count
      @public_items_count         = ScheduleItem.where(is_public: true).count
    end
  end
end
