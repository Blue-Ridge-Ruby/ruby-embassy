class LightningTalkSignupsController < ApplicationController
  before_action :load_schedule_item

  def create
    @signup = LightningTalkSignup.claim_next_slot!(
      user: current_user,
      schedule_item: @schedule_item
    )
    respond_to do |format|
      format.turbo_stream {
        render turbo_stream: turbo_stream.replace(
          helpers.dom_id(@schedule_item),
          partial: "schedule/session_item",
          locals: { item: @schedule_item, planned: true }
        )
      }
      format.html { redirect_back fallback_location: schedule_path, notice: "You're signed up to give a lightning talk." }
    end
  rescue LightningTalkSignup::SlotsFull
    redirect_back fallback_location: schedule_path, alert: "All speaking slots are full."
  end

  def edit
    @signup = current_signup
  end

  def update
    @signup = current_signup
    if @signup.update(signup_params)
      redirect_to schedule_path, notice: "Talk details saved."
    else
      render :edit, status: :unprocessable_content
    end
  end

  private

  def load_schedule_item
    @schedule_item = ScheduleItem.find(params[:schedule_item_id])
  end

  def current_signup
    current_user.lightning_talk_signups.find_by!(schedule_item_id: @schedule_item.id)
  end

  def signup_params
    params.require(:lightning_talk_signup).permit(:talk_title, :talk_description, :slides_url)
  end
end
