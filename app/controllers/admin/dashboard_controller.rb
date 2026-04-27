module Admin
  class DashboardController < AdminController
    def show
      @attendees_count            = User.attendee.count
      @embassy_applications_count = EmbassyApplication.submitted.where(passport_received_at: nil).count
      @rsvps_count                = PlanItem.joins(:schedule_item)
                                            .merge(ScheduleItem.where.not(kind: [ :talk, :reception, :volunteer ]))
                                            .count
      @volunteers_needed_count    = ScheduleItem.volunteer_empty
                                                .where(day: ScheduleItem.upcoming_day_keys)
                                                .count
    end
  end
end
