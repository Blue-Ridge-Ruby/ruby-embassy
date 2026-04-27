class Admin::NotaryProfilesController < AdminController
  before_action :set_notary, only: %i[edit update destroy]

  def index
    @notaries = NotaryProfile.order(:external_id)
  end

  def new
    @notary = NotaryProfile.new(status: "active")
  end

  def create
    @notary = NotaryProfile.new(notary_params)
    if @notary.save
      redirect_to admin_notary_profiles_path,
                  notice: "Notary added to the pool."
    else
      render :new, status: :unprocessable_content
    end
  end

  def edit
  end

  def update
    if @notary.update(notary_params)
      redirect_to admin_notary_profiles_path,
                  notice: "Notary updated."
    else
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    @notary.update!(status: "archived")
    redirect_to admin_notary_profiles_path,
                notice: "Notary archived."
  end

  private

  def set_notary
    @notary = NotaryProfile.find(params[:id])
  end

  def notary_params
    params.require(:notary_profile).permit(
      :external_id, :description, :followup_prompt, :status
    )
  end
end
