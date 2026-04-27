class DashboardController < ApplicationController
  before_action :authenticate_user!

  def show
    if current_user.volunteer? || current_user.admin?
      @empty_volunteer_count = ScheduleItem.volunteer_empty.count
    end
  end
end
