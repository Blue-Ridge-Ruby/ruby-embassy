require "test_helper"

class LightningTalkSignupTest < ActiveSupport::TestCase
  def lightning_item(overrides = {})
    ScheduleItem.create!({
      day: "fri",
      title: "Lightning Talks",
      kind: :lightning,
      sort_time: 1400,
      time_label: "2:00 PM",
      is_public: true
    }.merge(overrides))
  end

  def non_lightning_item
    ScheduleItem.create!(day: "fri", title: "Regular Talk", kind: :talk, is_public: true)
  end

  test "rejects signup for non-lightning schedule item" do
    item   = non_lightning_item
    signup = LightningTalkSignup.new(user: users(:attendee_one), schedule_item: item, position: 1)
    assert_not signup.valid?
    assert_includes signup.errors[:schedule_item], "must be a lightning talk"
  end

  test "uniqueness: same user cannot sign up twice" do
    item = lightning_item
    LightningTalkSignup.claim_next_slot!(user: users(:attendee_one), schedule_item: item)
    duplicate = LightningTalkSignup.new(user: users(:attendee_one), schedule_item: item, position: 2)
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:user_id], "has already been taken"
  end

  test "claim_next_slot! assigns positions 1, 2, 3 in creation order" do
    item = lightning_item
    s1 = LightningTalkSignup.claim_next_slot!(user: users(:attendee_one), schedule_item: item)
    s2 = LightningTalkSignup.claim_next_slot!(user: users(:volunteer_one), schedule_item: item)
    s3 = LightningTalkSignup.claim_next_slot!(user: users(:jeremy), schedule_item: item)
    assert_equal [ 1, 2, 3 ], [ s1.position, s2.position, s3.position ]
  end

  test "claim_next_slot! raises SlotsFull when at MAX_SPEAKERS" do
    item = lightning_item
    LightningTalkSignup::MAX_SPEAKERS.times do |i|
      user = User.create!(email: "filler-#{i}@example.com", role: :attendee)
      LightningTalkSignup.claim_next_slot!(user: user, schedule_item: item)
    end

    overflow_user = User.create!(email: "overflow@example.com", role: :attendee)
    assert_raises(LightningTalkSignup::SlotsFull) do
      LightningTalkSignup.claim_next_slot!(user: overflow_user, schedule_item: item)
    end
  end

  test "slot_start_label divides 60 minutes evenly across 5 signups" do
    item = lightning_item(sort_time: 1400, time_label: "2:00 PM")
    signups = 5.times.map do |i|
      user = User.create!(email: "s#{i}@example.com", role: :attendee)
      LightningTalkSignup.claim_next_slot!(user: user, schedule_item: item)
    end
    assert_equal "2:00 PM", signups[0].slot_start_label
    assert_equal "2:12 PM", signups[1].slot_start_label
    assert_equal "2:24 PM", signups[2].slot_start_label
    assert_equal "2:36 PM", signups[3].slot_start_label
    assert_equal "2:48 PM", signups[4].slot_start_label
  end

  test "slot_start_label uses 6-minute slots when 10 signups are filled" do
    item = lightning_item(sort_time: 1400, time_label: "2:00 PM")
    signups = LightningTalkSignup::MAX_SPEAKERS.times.map do |i|
      user = User.create!(email: "ten#{i}@example.com", role: :attendee)
      LightningTalkSignup.claim_next_slot!(user: user, schedule_item: item)
    end
    assert_equal "2:00 PM", signups[0].slot_start_label
    assert_equal "2:06 PM", signups[1].slot_start_label
    assert_equal "2:54 PM", signups[9].slot_start_label
  end

  test "creating a signup creates a matching PlanItem" do
    item = lightning_item
    user = users(:attendee_one)
    assert_difference -> { PlanItem.where(user: user, schedule_item: item).count }, 1 do
      LightningTalkSignup.claim_next_slot!(user: user, schedule_item: item)
    end
  end

  test "creating a signup is idempotent with existing PlanItem" do
    item = lightning_item
    user = users(:attendee_one)
    PlanItem.create!(user: user, schedule_item: item)
    assert_no_difference -> { PlanItem.count } do
      LightningTalkSignup.claim_next_slot!(user: user, schedule_item: item)
    end
  end

  test "editable_by? admin can edit any signup" do
    item   = lightning_item
    signup = LightningTalkSignup.claim_next_slot!(user: users(:attendee_one), schedule_item: item)
    assert signup.editable_by?(users(:jeremy))
  end

  test "editable_by? speaker can edit own signup" do
    item   = lightning_item
    signup = LightningTalkSignup.claim_next_slot!(user: users(:attendee_one), schedule_item: item)
    assert signup.editable_by?(users(:attendee_one))
  end

  test "editable_by? other attendee cannot edit" do
    item   = lightning_item
    signup = LightningTalkSignup.claim_next_slot!(user: users(:attendee_one), schedule_item: item)
    assert_not signup.editable_by?(users(:volunteer_one))
  end

  test "editable_by? nil actor returns false" do
    item   = lightning_item
    signup = LightningTalkSignup.claim_next_slot!(user: users(:attendee_one), schedule_item: item)
    assert_not signup.editable_by?(nil)
  end
end
