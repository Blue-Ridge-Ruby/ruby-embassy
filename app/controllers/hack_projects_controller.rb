class HackProjectsController < ApplicationController
  before_action :set_schedule_item
  before_action :require_hack_day!
  before_action :set_hack_project, only: %i[show edit update]
  before_action :require_editable!, only: %i[edit update]
  before_action :require_not_hosting!, only: %i[new create]

  def index
    @hack_projects = @schedule_item.hack_projects
                                   .includes(:host, hack_project_signups: :user)
                                   .order(:created_at)
    @current_user_signup = HackProjectSignup.find_by(user: current_user, schedule_item: @schedule_item)
    @current_user_hosted_project = @schedule_item.hack_projects.find_by(host_id: current_user.id)
  end

  def show
    @current_user_signup = HackProjectSignup.find_by(user: current_user, hack_project: @hack_project)
  end

  def new
    @hack_project = @schedule_item.hack_projects.new
  end

  def create
    @hack_project = @schedule_item.hack_projects.new(hack_project_params)
    @hack_project.host = current_user
    host_role = params.dig(:hack_project, :host_role)

    HackProject.transaction do
      @hack_project.save!
      remove_existing_signup_for_event!
      @hack_project.hack_project_signups.create!(
        user: current_user,
        schedule_item: @schedule_item,
        role: host_role
      )
    end

    redirect_to schedule_item_hack_projects_path(@schedule_item),
                notice: "Project added. You're a #{host_role} on #{@hack_project.title}."
  rescue ActiveRecord::RecordInvalid
    render :new, status: :unprocessable_content
  end

  def edit; end

  def update
    if @hack_project.update(hack_project_params)
      redirect_to schedule_item_hack_projects_path(@schedule_item), notice: "Project updated."
    else
      render :edit, status: :unprocessable_content
    end
  end

  private

  def set_schedule_item
    @schedule_item = ScheduleItem.find(params[:schedule_item_id])
  end

  def require_hack_day!
    return if @schedule_item.hack_day?
    raise ActiveRecord::RecordNotFound
  end

  def set_hack_project
    @hack_project = @schedule_item.hack_projects.find(params[:id])
  end

  def require_editable!
    return if @hack_project.editable_by?(current_user)
    redirect_to schedule_item_hack_projects_path(@schedule_item),
                alert: "Only the host or an admin can edit this project."
  end

  def require_not_hosting!
    existing = @schedule_item.hack_projects.find_by(host_id: current_user.id)
    return unless existing
    redirect_to schedule_item_hack_project_path(@schedule_item, existing),
                alert: "You're already hosting #{existing.title}. " \
                       "Only one hosted project per person."
  end

  def hack_project_params
    params.require(:hack_project).permit(
      :title, :repo_url, :description, :contributors_guide_url, :skill_level
    )
  end

  def remove_existing_signup_for_event!
    HackProjectSignup.where(user: current_user, schedule_item: @schedule_item).destroy_all
  end
end
