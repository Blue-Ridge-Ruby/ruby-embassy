class PlanController < ApplicationController
  # Travel times are mocked until we wire up arrival_at/departure_at on User.
  MOCK_TRAVEL = {
    arrival: "2026-04-29T15:30",
    departure: "2026-05-02T20:00"
  }.freeze

  def index
    @plan_items_by_day = current_user.plan_items
                                     .includes(:schedule_item)
                                     .sort_by { |pi| [ ScheduleItem::DAY_META.keys.index(pi.schedule_item.day) || 99, pi.schedule_item.sort_time.to_i ] }
                                     .group_by { |pi| pi.schedule_item.day }

    @speaking_ids = current_user.lightning_talk_signups.pluck(:schedule_item_id).to_set
    @travel       = MOCK_TRAVEL
  end
end
