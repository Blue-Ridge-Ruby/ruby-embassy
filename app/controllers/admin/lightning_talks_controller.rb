module Admin
  class LightningTalksController < AdminController
    def index
      @lightning_items = ScheduleItem.lightning.ordered.includes(:lightning_talk_signups)
    end
  end
end
