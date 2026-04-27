module Admin
  class HackProjectsController < AdminController
    before_action :set_hack_day
    before_action :set_hack_project, only: %i[show edit update destroy]

    def index
      @hack_projects = @hack_day.hack_projects
                                .includes(:host, hack_project_signups: :user)
                                .order(:created_at)
    end

    def show; end

    def new
      @hack_project = @hack_day.hack_projects.new
    end

    def create
      @hack_project = @hack_day.hack_projects.new(hack_project_params)
      @hack_project.host_id = params.dig(:hack_project, :host_id)
      host_role = params.dig(:hack_project, :host_role)

      HackProject.transaction do
        @hack_project.save!
        @hack_project.hack_project_signups.create!(
          user_id: @hack_project.host_id,
          schedule_item: @hack_day,
          role: host_role
        )
      end

      redirect_to admin_hack_projects_path,
                  notice: "Created project: #{@hack_project.title}."
    rescue ActiveRecord::RecordInvalid
      render :new, status: :unprocessable_content
    end

    def edit; end

    def update
      if @hack_project.update(hack_project_params)
        redirect_to admin_hack_projects_path, notice: "Updated project: #{@hack_project.title}."
      else
        render :edit, status: :unprocessable_content
      end
    end

    def destroy
      title = @hack_project.title
      @hack_project.destroy
      redirect_to admin_hack_projects_path, notice: "Removed project: #{title}."
    end

    private

    def set_hack_day
      @hack_day = ScheduleItem.find_by!(slug: ScheduleItem::HACK_DAY_SLUG)
    end

    def set_hack_project
      @hack_project = HackProject.find(params[:id])
    end

    def hack_project_params
      params.require(:hack_project).permit(
        :title, :repo_url, :description, :contributors_guide_url, :skill_level
      )
    end
  end
end
