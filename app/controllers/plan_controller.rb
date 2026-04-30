class PlanController < ApplicationController
  # Travel section hidden in view — see app/views/plan/index.html.erb.
  # MOCK_TRAVEL = {
  #   arrival: "2026-04-29T15:30",
  #   departure: "2026-05-02T20:00"
  # }.freeze

  def index
    @show_past = params[:show_past].present?

    all_plan_items = current_user.plan_items.includes(:schedule_item)
    @days_with_any_plan_items = all_plan_items.map { |pi| pi.schedule_item.day }.to_set

    visible_plan_items = @show_past ? all_plan_items : all_plan_items.reject { |pi| pi.schedule_item.passed? }

    @plan_items_by_day = visible_plan_items
      .sort_by { |pi| [ ScheduleItem::DAY_META.keys.index(pi.schedule_item.day) || 99, pi.schedule_item.sort_time.to_i ] }
      .group_by { |pi| pi.schedule_item.day }

    @speaking_ids = current_user.lightning_talk_signups.pluck(:schedule_item_id).to_set
    # @travel = MOCK_TRAVEL
  end
end
