module Admin
  class LightningTalksController < AdminController
    def index
      @schedule_item = ScheduleItem.lightning.ordered.first
    end
  end
end
