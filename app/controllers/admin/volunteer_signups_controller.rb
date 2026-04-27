class Admin::VolunteerSignupsController < AdminController
  def create
    user = User.where(role: [ :volunteer, :admin ]).find(params[:user_id])
    slot = ScheduleItem.volunteer.find(params[:schedule_item_id])
    PlanItem.create!(user: user, schedule_item: slot)
    redirect_back fallback_location: admin_volunteers_path,
                  notice: "Assigned #{user.full_name} to #{slot.title}."
  rescue ActiveRecord::RecordInvalid => e
    redirect_back fallback_location: admin_volunteers_path, alert: e.message
  end

  def destroy
    plan_item = PlanItem.find(params[:id])
    user_name = plan_item.user.full_name
    title     = plan_item.schedule_item.title
    plan_item.destroy
    redirect_back fallback_location: admin_volunteers_path,
                  notice: "Removed #{user_name} from #{title}."
  end
end
