require "test_helper"

class SeedTest < ActiveSupport::TestCase
  self.use_transactional_tests = false

  setup do
    User.where(email: [ "jeremy@blueridgeruby.com", "katyasarmientodev@gmail.com" ]).destroy_all
    ScheduleItem.where.not(id: nil).destroy_all
  end

  teardown do
    User.where(email: [ "jeremy@blueridgeruby.com", "katyasarmientodev@gmail.com" ]).destroy_all
    ScheduleItem.where.not(id: nil).destroy_all
  end

  test "seed makes jeremy and katya admins, idempotently" do
    2.times { Rails.application.load_seed }

    assert User.find_by(email: "jeremy@blueridgeruby.com").admin?
    assert User.find_by(email: "katyasarmientodev@gmail.com").admin?
  end

  test "seed upserts every YAML row as a public ScheduleItem" do
    Rails.application.load_seed

    yaml_count = YAML.load_file(Rails.root.join("config/schedule.yml"), permitted_classes: [ Symbol ])[:days]
                     .sum { |d| d[:items].size }
    assert_equal yaml_count, ScheduleItem.count
    assert_equal yaml_count, ScheduleItem.public_items.count
  end

  test "seed is idempotent for schedule_items" do
    Rails.application.load_seed
    count_after_first = ScheduleItem.count
    Rails.application.load_seed
    assert_equal count_after_first, ScheduleItem.count
  end

  test "seeded talks carry title (topic) and host (speaker)" do
    Rails.application.load_seed

    talk = ScheduleItem.find_by(slug: "thu-talk-1")
    assert_equal "John Athayde", talk.host
    assert talk.title.start_with?("Learning from Permaculture"), "talk title should be the topic, not the speaker"
    assert talk.talk?
  end

  test "seeded logistics (registration/welcome/coffee) are kind: embassy" do
    Rails.application.load_seed

    %w[thu-registration thu-welcome fri-coffee].each do |slug|
      item = ScheduleItem.find_by(slug: slug)
      assert_equal "embassy", item.kind, "#{slug} should be kind: embassy"
    end
  end

  test "seeded social items are kind: activity" do
    Rails.application.load_seed

    %w[wed-meetup thu-lunch thu-dinner fri-afterparty sat-evening].each do |slug|
      item = ScheduleItem.find_by(slug: slug)
      assert_equal "activity", item.kind, "#{slug} should be kind: activity"
    end
  end
end
