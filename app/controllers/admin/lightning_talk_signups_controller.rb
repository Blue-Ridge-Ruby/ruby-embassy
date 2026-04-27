require "csv"

module Admin
  class LightningTalkSignupsController < AdminController
    before_action :load_schedule_item
    before_action :set_signup, only: %i[update destroy]

    def index
      @signups = @schedule_item.lightning_talk_signups.includes(:user)
      respond_to do |format|
        format.html
        format.csv { send_data signups_csv(@signups), filename: csv_filename, type: "text/csv" }
      end
    end

    def create
      user = User.find(params[:user_id])
      LightningTalkSignup.claim_next_slot!(user: user, schedule_item: @schedule_item)
      redirect_to admin_schedule_item_lightning_talk_signups_path(@schedule_item),
                  notice: "Speaker added."
    rescue LightningTalkSignup::SlotsFull
      redirect_to admin_schedule_item_lightning_talk_signups_path(@schedule_item),
                  alert: "All speaking slots are full."
    end

    def update
      if @signup.update(signup_params)
        redirect_to admin_schedule_item_lightning_talk_signups_path(@schedule_item),
                    notice: "Talk details updated."
      else
        redirect_to admin_schedule_item_lightning_talk_signups_path(@schedule_item),
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
      redirect_to admin_schedule_item_lightning_talk_signups_path(@schedule_item),
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

    def signups_csv(signups)
      CSV.generate do |csv|
        csv << %w[position slot_time first_name last_name email talk_title talk_description slides_url]
        signups.each do |s|
          csv << [
            s.position,
            s.slot_start_label,
            s.user.first_name,
            s.user.last_name,
            s.user.email,
            s.talk_title,
            s.talk_description,
            s.slides_url
          ]
        end
      end
    end

    def csv_filename
      "lightning-talks-#{@schedule_item.day}-#{@schedule_item.id}.csv"
    end
  end
end
