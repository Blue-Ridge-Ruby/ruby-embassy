# Schedule seed — runnable independently in production:
#   rails runner db/seeds/schedule.rb
#
# Idempotent: upserts ScheduleItem records by slug, then removes obsolete
# slugs from prior schedule versions. Safe to run repeatedly.

schedule_data = YAML.load_file(
  Rails.root.join("config/schedule.yml"),
  permitted_classes: [ Symbol ]
)

schedule_data[:days].each do |day|
  day[:items].each do |item|
    record = ScheduleItem.find_or_initialize_by(slug: item[:id])
    record.day         = day[:anchor]
    record.time_label  = item[:time]
    record.sort_time   = item[:sort_time]
    record.title       = item[:title]
    record.host        = item[:host]
    record.host_url    = item[:host_url]
    record.location    = item[:location]
    record.map_url     = item[:map_url]
    record.description = item[:description]
    record.kind        = item[:type]
    record.flexible    = item[:flexible] || false
    record.is_public   = true
    record.created_by  = nil
    record.save!
  end
end

# Remove slugs that existed in earlier schedule versions but are no longer
# part of the canonical schedule. Cascades to plan_items via dependent: :destroy.
obsolete_slugs = %w[sat-morning sat-afternoon sat-evening sat-embassy-am sat-embassy-pm]
ScheduleItem.where(slug: obsolete_slugs).destroy_all
