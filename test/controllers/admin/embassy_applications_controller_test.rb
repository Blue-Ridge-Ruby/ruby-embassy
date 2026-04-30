require "test_helper"

class Admin::EmbassyApplicationsControllerTest < ActionDispatch::IntegrationTest
  def create_application_for(user, schedule_item)
    plan_item = user.plan_items.create!(schedule_item: schedule_item)
    booking = EmbassyBooking.create!(
      user: user, schedule_item: schedule_item, plan_item: plan_item,
      mode: "new_passport", state: "confirmed"
    )
    EmbassyApplication.create!(
      embassy_booking: booking,
      state: "submitted",
      submitted_at: Time.current,
      drawn_question_ids: [],
      notary_profile_id: nil
    )
  end

  setup do
    @passport_block = ScheduleItem.create!(
      day: "thu", title: "Passport Block", kind: :embassy, is_public: true,
      offers_new_passport: true, new_passport_capacity: 4
    )
    @pickup_block = ScheduleItem.create!(
      day: "sat", title: "Pickup Block", kind: :embassy, is_public: true,
      offers_passport_pickup: true, passport_pickup_capacity: 2,
      time_label: "2:00 PM", sort_time: 1400
    )
    @attendee = users(:attendee_one)
    @application = create_application_for(@attendee, @passport_block)
  end

  test "schedule_pickup creates a passport_pickup booking for the applicant" do
    sign_in_as users(:jeremy)
    assert_difference -> { EmbassyBooking.where(mode: "passport_pickup").count }, 1 do
      post schedule_pickup_admin_embassy_application_path(@application.serial),
           params: { schedule_item_id: @pickup_block.id }
    end
    booking = EmbassyBooking.where(mode: "passport_pickup").last
    assert_equal @attendee, booking.user
    assert_equal @pickup_block, booking.schedule_item
    assert_equal "confirmed", booking.state
  end

  test "schedule_pickup rejects blocks that don't offer pickup" do
    sign_in_as users(:jeremy)
    assert_no_difference -> { EmbassyBooking.where(mode: "passport_pickup").count } do
      post schedule_pickup_admin_embassy_application_path(@application.serial),
           params: { schedule_item_id: @passport_block.id }
    end
    follow_redirect!
    assert_match(/set up for passport pickup/, response.body)
  end

  test "schedule_pickup rejects when pickup capacity is full" do
    @pickup_block.update!(passport_pickup_capacity: 1)
    other = users(:volunteer_one)
    other_plan = other.plan_items.create!(schedule_item: @pickup_block)
    EmbassyBooking.create!(user: other, schedule_item: @pickup_block, plan_item: other_plan,
                           mode: "passport_pickup", state: "confirmed")

    sign_in_as users(:jeremy)
    assert_no_difference -> { EmbassyBooking.where(mode: "passport_pickup").count } do
      post schedule_pickup_admin_embassy_application_path(@application.serial),
           params: { schedule_item_id: @pickup_block.id }
    end
  end

  test "non-admins cannot schedule pickup" do
    sign_in_as users(:attendee_one)
    post schedule_pickup_admin_embassy_application_path(@application.serial),
         params: { schedule_item_id: @pickup_block.id }
    assert_response :not_found
  end

  test "destroy wipes the application, booking, plan_item, and answers" do
    question = Question.create!(
      external_id: "Q-DESTROY-1", section: 1, position: 1,
      label: "Sample", field_type: "short", scope: "common", status: "active"
    )
    EmbassyApplicationAnswer.create!(embassy_application: @application, question: question, value_text: "hi")
    booking = @application.embassy_booking
    booking_id = booking.id
    plan_item_id = booking.plan_item_id
    application_id = @application.id

    sign_in_as users(:jeremy)
    assert_difference -> { EmbassyApplication.count }, -1 do
      assert_difference -> { EmbassyApplicationAnswer.count }, -1 do
        assert_difference -> { EmbassyBooking.count }, -1 do
          assert_difference -> { PlanItem.count }, -1 do
            delete admin_embassy_application_path(@application.serial)
          end
        end
      end
    end

    assert_redirected_to admin_embassy_applications_path
    assert_match(/Deleted application/, flash[:notice])
    assert_not EmbassyApplication.exists?(application_id)
    assert_not EmbassyBooking.exists?(booking_id)
    assert_not PlanItem.exists?(plan_item_id)
    assert Question.exists?(question.id), "question should not be touched"
  end

  test "non-admins cannot destroy applications" do
    sign_in_as users(:attendee_one)
    assert_no_difference -> { EmbassyApplication.count } do
      delete admin_embassy_application_path(@application.serial)
    end
    assert_response :not_found
  end

  test "mark_ready stamps ready_at on the application" do
    sign_in_as users(:jeremy)
    assert_nil @application.ready_at
    patch mark_ready_admin_embassy_application_path(@application.serial)
    assert_not_nil @application.reload.ready_at
    assert_match(/ready for pickup/, flash[:notice])
  end

  test "unmark_ready clears ready_at" do
    @application.update!(ready_at: Time.current)
    sign_in_as users(:jeremy)
    patch unmark_ready_admin_embassy_application_path(@application.serial)
    assert_nil @application.reload.ready_at
    assert_match(/Cleared ready status/, flash[:notice])
  end

  test "non-admins cannot mark ready" do
    sign_in_as users(:attendee_one)
    patch mark_ready_admin_embassy_application_path(@application.serial)
    assert_response :not_found
    assert_nil @application.reload.ready_at
  end
end
