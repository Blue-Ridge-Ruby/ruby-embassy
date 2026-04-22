class ScheduleController < ApplicationController
  SCHEDULE_PATH = Rails.root.join("config", "schedule.yml")

  def index
    data = YAML.load_file(SCHEDULE_PATH, permitted_classes: [ Symbol ])
    @days = data[:days]
  end
end
