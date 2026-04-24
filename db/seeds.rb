# Seeds are idempotent — safe to run repeatedly, including in production.

# 1. Admin users. find_or_initialize_by + explicit save! ensures an existing
#    row gets updated to role: :admin (e.g., if Jeremy already exists in prod
#    but with a different role, this corrects it).
admin_users = [
  { email: "jeremy@blueridgeruby.com",    first_name: "Jeremy", last_name: "Smith" },
  { email: "katyasarmientodev@gmail.com", first_name: "Katya",  last_name: "Sarmiento" }
]

admin_users.each do |attrs|
  user = User.find_or_initialize_by(email: attrs[:email])
  user.first_name ||= attrs[:first_name]
  user.last_name  ||= attrs[:last_name]
  user.role = :admin
  user.save!
end

# 2. Canonical schedule from config/schedule.yml. Upsert by slug so re-runs
#    never duplicate. After seeding, admins edit via /admin/schedule_items;
#    the YAML is reference data.
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
    record.location    = item[:location]
    record.description = item[:description]
    record.kind        = item[:type]
    record.flexible    = item[:flexible] || false
    record.is_public   = true
    record.created_by  = nil
    record.save!
  end
end
