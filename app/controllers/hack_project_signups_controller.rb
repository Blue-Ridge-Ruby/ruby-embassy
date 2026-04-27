class HackProjectSignupsController < ApplicationController
  before_action :set_schedule_item
  before_action :set_hack_project

  def create
    role = params.dig(:hack_project_signup, :role)

    HackProjectSignup.transaction do
      remove_existing_signup_for_event!
      @hack_project.hack_project_signups.create!(
        user: current_user,
        schedule_item: @schedule_item,
        role: role
      )
    end

    redirect_to schedule_item_hack_projects_path(@schedule_item),
                notice: "You're signed up as a #{role} on #{@hack_project.title}."
  rescue ActiveRecord::RecordInvalid => e
    redirect_to schedule_item_hack_projects_path(@schedule_item),
                alert: e.record.errors.full_messages.to_sentence.presence ||
                       "Couldn't sign up — please try again."
  end

  def update
    signup = current_user_signup_for_project
    return redirect_back(fallback_location: schedule_item_hack_projects_path(@schedule_item),
                         alert: "You're not signed up to this project.") unless signup

    if signup.update(role: params.dig(:hack_project_signup, :role))
      redirect_to schedule_item_hack_projects_path(@schedule_item),
                  notice: "Role updated to #{signup.role}."
    else
      redirect_to schedule_item_hack_projects_path(@schedule_item),
                  alert: signup.errors.full_messages.to_sentence
    end
  end

  def destroy
    signup = current_user_signup_for_project
    signup&.destroy

    redirect_to schedule_item_hack_projects_path(@schedule_item),
                notice: "You've left #{@hack_project.title}. You're still RSVPed to Hack Day."
  end

  private

  def set_schedule_item
    @schedule_item = ScheduleItem.find(params[:schedule_item_id])
    raise ActiveRecord::RecordNotFound unless @schedule_item.hack_day?
  end

  def set_hack_project
    @hack_project = @schedule_item.hack_projects.find(params[:hack_project_id])
  end

  def current_user_signup_for_project
    @hack_project.hack_project_signups.find_by(user: current_user)
  end

  def remove_existing_signup_for_event!
    HackProjectSignup.where(user: current_user, schedule_item: @schedule_item).destroy_all
  end
end
