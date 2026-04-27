class Admin::VolunteersController < AdminController
  before_action :set_volunteer, only: %i[show]

  def index
    @volunteers  = User.where(role: [ :volunteer, :admin ])
                       .order(:last_name, :first_name)
    @slot_counts = PlanItem.joins(:schedule_item)
                           .merge(ScheduleItem.volunteer)
                           .group(:user_id)
                           .count
  end

  def show
    @slots = @volunteer.plan_items
                       .joins(:schedule_item)
                       .merge(ScheduleItem.volunteer)
                       .includes(:schedule_item)
                       .sort_by { |pi|
                         [
                           ScheduleItem::DAY_META.keys.index(pi.schedule_item.day) || 99,
                           pi.schedule_item.sort_time.to_i
                         ]
                       }
    signed_up_ids = @slots.map(&:schedule_item_id)
    @available_slots = ScheduleItem.volunteer
                                   .where.not(id: signed_up_ids)
                                   .ordered
  end

  private

  def set_volunteer
    @volunteer = User.where(role: [ :volunteer, :admin ]).find(params[:id])
  end
end
