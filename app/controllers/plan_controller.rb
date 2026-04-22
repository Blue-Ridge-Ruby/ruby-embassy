class PlanController < ApplicationController
  SCHEDULE_PATH = Rails.root.join("config", "schedule.yml")

  # Hardcoded notes and custom blocks for the static design mockup.
  # Real user data will replace this in a later pass.
  MOCK_NOTES = {
    "wed-meetup" => "Meet Sam by the bar",
    "thu-talk-1" => "Sit near the front"
  }.freeze

  MOCK_CUSTOM_BLOCKS = {
    "thu" => [
      {
        id: "custom-1",
        time: "6:30 PM",
        sort_time: 1830,
        title: "Dinner with RailsConf crew",
        custom: true,
        notes: "Tupelo Honey on Biltmore Ave"
      }
    ]
  }.freeze

  MOCK_TRAVEL = {
    arrival: "2025-04-29T15:30",
    departure: "2025-05-02T20:00"
  }.freeze

  def index
    data = YAML.load_file(SCHEDULE_PATH, permitted_classes: [ Symbol ])
    @days = data[:days].map { |day| build_plan_day(day) }
    @travel = MOCK_TRAVEL
  end

  private

  def build_plan_day(day)
    added_items = day[:items].select { |item| item[:added] }.map do |item|
      item.merge(notes: MOCK_NOTES[item[:id]])
    end

    custom = MOCK_CUSTOM_BLOCKS[day[:anchor].to_s] || []

    {
      anchor: day[:anchor],
      date: day[:date],
      label: day[:label],
      subtitle: day[:subtitle],
      items: (added_items + custom).sort_by { |i| i[:sort_time] }
    }
  end
end
