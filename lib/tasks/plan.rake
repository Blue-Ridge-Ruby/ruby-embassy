namespace :plan do
  desc "Create default PlanItems (talks + receptions) for all existing users"
  task backfill_defaults: :environment do
    User.find_each do |user|
      user.materialize_default_plan_items
      print "."
    end
    puts "\nDone."
  end
end
