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

  test "seeded reception items (registration/welcome/breaks/coffee/closing) are kind: reception" do
    Rails.application.load_seed

    %w[thu-registration thu-welcome thu-break-1 thu-closing fri-coffee fri-welcome fri-closing].each do |slug|
      item = ScheduleItem.find_by(slug: slug)
      assert_equal "reception", item.kind, "#{slug} should be kind: reception"
    end
  end

  test "seeded meal items (lunches and dinners) are kind: meal" do
    Rails.application.load_seed

    %w[thu-lunch thu-dinner fri-lunch fri-dinner].each do |slug|
      item = ScheduleItem.find_by(slug: slug)
      assert_equal "meal", item.kind, "#{slug} should be kind: meal"
    end
  end

  test "seeded community items (in-event participatory + offsite social) are kind: community" do
    Rails.application.load_seed

    %w[wed-meetup thu-mystery thu-roundtable fri-afterparty sat-hackday].each do |slug|
      item = ScheduleItem.find_by(slug: slug)
      assert_equal "community", item.kind, "#{slug} should be kind: community"
    end
  end

  test "seeded activity items (external with capacity concerns) are kind: activity" do
    Rails.application.load_seed

    %w[sat-dinner].each do |slug|
      item = ScheduleItem.find_by(slug: slug)
      assert_equal "activity", item.kind, "#{slug} should be kind: activity"
    end
  end
end
