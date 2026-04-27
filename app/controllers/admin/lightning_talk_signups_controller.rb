module Admin
  class LightningTalkSignupsController < AdminController
    before_action :load_schedule_item
    before_action :set_signup, only: %i[update destroy]

    def index
      respond_to do |format|
        format.html { redirect_to admin_lightning_talks_path }
        format.pdf {
          send_data LightningTalksPdf.new(@schedule_item).render,
                    filename: pdf_filename,
                    type: "application/pdf",
                    disposition: "attachment"
        }
      end
    end

    def create
      user = User.find(params[:user_id])
      LightningTalkSignup.claim_next_slot!(user: user, schedule_item: @schedule_item)
      redirect_back fallback_location: admin_lightning_talks_path,
                    notice: "Speaker added."
    rescue LightningTalkSignup::SlotsFull
      redirect_back fallback_location: admin_lightning_talks_path,
                    alert: "All speaking slots are full."
    end

    def update
      if @signup.update(signup_params)
        redirect_back fallback_location: admin_lightning_talks_path,
                      notice: "Talk details updated."
      else
        redirect_back fallback_location: admin_lightning_talks_path,
                      alert: @signup.errors.full_messages.to_sentence
      end
    end

    def destroy
      removed_position = @signup.position
      LightningTalkSignup.transaction do
        @signup.destroy!
        @schedule_item.lightning_talk_signups
                      .where("position > ?", removed_position)
                      .order(:position)
                      .each { |s| s.update_columns(position: s.position - 1) }
      end
      redirect_back fallback_location: admin_lightning_talks_path,
                    notice: "Speaker removed."
    end

    def reorder
      ids = Array(params[:signup_ids]).map(&:to_i)
      LightningTalkSignup.transaction do
        signups = @schedule_item.lightning_talk_signups.where(id: ids).index_by(&:id)
        # Two-pass renumber to avoid colliding with the unique [schedule_item_id, position] index.
        signups.each_value { |s| s.update_columns(position: s.position + LightningTalkSignup::MAX_SPEAKERS) }
        ids.each_with_index do |id, index|
          signups[id]&.update_columns(position: index + 1)
        end
      end
      head :no_content
    end

    private

    def load_schedule_item
      @schedule_item = ScheduleItem.find(params[:schedule_item_id])
    end

    def set_signup
      @signup = @schedule_item.lightning_talk_signups.find(params[:id])
    end

    def signup_params
      params.require(:lightning_talk_signup).permit(:talk_title, :talk_description, :slides_url)
    end

    def pdf_filename
      "lightning-talks-#{@schedule_item.day}-#{@schedule_item.id}.pdf"
    end
  end
end
