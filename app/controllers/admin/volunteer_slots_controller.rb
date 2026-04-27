class Admin::VolunteerSlotsController < AdminController
  before_action :set_slot, only: %i[show]

  def index
    @slots = ScheduleItem.volunteer.ordered
  end

  def show
    @signups = @slot.plan_items.includes(:user)
    signed_up_ids = @signups.map(&:user_id)
    @available_volunteers = User.where(role: [ :volunteer, :admin ])
                                .where.not(id: signed_up_ids)
                                .order(:last_name, :first_name)
  end

  private

  def set_slot
    @slot = ScheduleItem.volunteer.find(params[:id])
  end
end
