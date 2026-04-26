namespace :db do
  namespace :seed do
    desc "Seed content (schedule items + embassy questions/notary pool); skips admin users"
    task content: :environment do
      load Rails.root.join("db/seeds/schedule.rb").to_s

      require Rails.root.join("db/seeds/embassy_questions").to_s
      EmbassyQuestionsSeed.import!

      puts "Seeded: #{ScheduleItem.count} schedule items · " \
           "#{Question.count} questions · " \
           "#{NotaryProfile.count} notary profiles"
    end
  end
end
