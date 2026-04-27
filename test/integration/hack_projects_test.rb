require "test_helper"

class HackProjectsTest < ActionDispatch::IntegrationTest
  setup do
    @hack_day = ScheduleItem.create!(
      slug: "sat-hackday",
      day: "sat",
      time_label: "9:00 AM",
      sort_time: 900,
      title: "Hack Day",
      kind: :community,
      is_public: true
    )
    @alice = users(:attendee_one)
    @vic   = users(:volunteer_one)
  end

  test "schedule page shows hack day with propose-a-project link when empty" do
    sign_in_as @alice
    get schedule_path
    assert_response :success
    assert_match "Hack Day", @response.body
    assert_match "Propose a project", @response.body
  end

  test "alice proposes a project and becomes the host + mentor" do
    sign_in_as @alice

    assert_difference -> { HackProject.count } => 1,
                      -> { HackProjectSignup.count } => 1,
                      -> { PlanItem.count } => 1 do
      post schedule_item_hack_projects_path(@hack_day),
           params: { hack_project: {
             title: "Better error messages",
             repo_url: "https://github.com/example/errors",
             description: "Make AR errors human-readable",
             host_role: "mentor"
           } }
    end

    project = HackProject.last
    assert_equal @alice, project.host
    assert project.hack_project_signups.find_by(user: @alice).mentor?
    assert PlanItem.find_by(user: @alice, schedule_item: @hack_day).hack_role_mentor?
  end

  test "vic joins alice's project as mentee" do
    project = HackProject.create!(
      schedule_item: @hack_day, host: @alice,
      title: "Foo", repo_url: "https://github.com/x/y"
    )
    project.hack_project_signups.create!(user: @alice, schedule_item: @hack_day, role: :mentor)

    sign_in_as @vic
    post schedule_item_hack_project_hack_project_signup_path(@hack_day, project),
         params: { hack_project_signup: { role: "mentee" } }

    assert_redirected_to schedule_item_hack_projects_path(@hack_day)
    signup = HackProjectSignup.find_by(user: @vic, hack_project: project)
    assert signup.mentee?
    assert PlanItem.find_by(user: @vic, schedule_item: @hack_day).hack_role_mentee?
  end

  test "vic switches role from mentee to mentor" do
    project = HackProject.create!(
      schedule_item: @hack_day, host: @alice,
      title: "Foo", repo_url: "https://github.com/x/y"
    )
    project.hack_project_signups.create!(user: @vic, schedule_item: @hack_day, role: :mentee)

    sign_in_as @vic
    patch schedule_item_hack_project_hack_project_signup_path(@hack_day, project),
          params: { hack_project_signup: { role: "mentor" } }

    assert HackProjectSignup.find_by(user: @vic).mentor?
    assert PlanItem.find_by(user: @vic, schedule_item: @hack_day).hack_role_mentor?
  end

  test "vic cannot edit alice's project" do
    project = HackProject.create!(
      schedule_item: @hack_day, host: @alice,
      title: "Foo", repo_url: "https://github.com/x/y"
    )

    sign_in_as @vic
    get edit_schedule_item_hack_project_path(@hack_day, project)
    assert_redirected_to schedule_item_hack_projects_path(@hack_day)
    assert_match "Only the host or an admin", flash[:alert]
  end

  test "leaving a project keeps the parent PlanItem" do
    project = HackProject.create!(
      schedule_item: @hack_day, host: @alice,
      title: "Foo", repo_url: "https://github.com/x/y"
    )
    project.hack_project_signups.create!(user: @vic, schedule_item: @hack_day, role: :mentee)

    sign_in_as @vic
    delete schedule_item_hack_project_hack_project_signup_path(@hack_day, project)

    assert_nil HackProjectSignup.find_by(user: @vic, hack_project: project)
    plan_item = PlanItem.find_by(user: @vic, schedule_item: @hack_day)
    assert plan_item.present?, "PlanItem should persist after leaving a project"
    assert plan_item.hack_role_mentee?, "hack_role should be retained"
  end

  test "user already hosting a project is redirected away from the new form" do
    HackProject.create!(
      schedule_item: @hack_day, host: @alice,
      title: "Already hosting", repo_url: "https://github.com/x/y"
    )

    sign_in_as @alice
    get new_schedule_item_hack_project_path(@hack_day)

    assert_response :redirect
    assert_match "already hosting Already hosting", flash[:alert]
  end

  test "user already hosting cannot create a second project" do
    HackProject.create!(
      schedule_item: @hack_day, host: @alice,
      title: "First", repo_url: "https://github.com/x/first"
    )

    sign_in_as @alice
    assert_no_difference -> { HackProject.count } do
      post schedule_item_hack_projects_path(@hack_day),
           params: { hack_project: {
             title: "Second", repo_url: "https://github.com/x/second", host_role: "mentor"
           } }
    end

    assert_response :redirect
    assert_match "already hosting", flash[:alert]
  end

  test "model validation blocks a duplicate host even outside the controller" do
    HackProject.create!(
      schedule_item: @hack_day, host: @alice,
      title: "First", repo_url: "https://github.com/x/first"
    )

    duplicate = HackProject.new(
      schedule_item: @hack_day, host: @alice,
      title: "Second", repo_url: "https://github.com/x/second"
    )
    refute duplicate.valid?
    assert_includes duplicate.errors.full_messages,
                    "Host is already hosting another Hack Day project"
  end

  test "vic cannot host a project on a non-hack-day schedule item" do
    other = ScheduleItem.create!(
      slug: "thu-other", day: "thu", time_label: "1pm", sort_time: 1300,
      title: "Other", kind: :community, is_public: true
    )

    sign_in_as @vic
    post schedule_item_hack_projects_path(other),
         params: { hack_project: {
           title: "x", repo_url: "https://x.com", host_role: "mentor"
         } }

    assert_response :not_found
  end

  test "admin can destroy a project" do
    project = HackProject.create!(
      schedule_item: @hack_day, host: @alice,
      title: "Foo", repo_url: "https://github.com/x/y"
    )
    project.hack_project_signups.create!(user: @alice, schedule_item: @hack_day, role: :mentor)

    sign_in_as users(:jeremy)
    delete admin_hack_project_path(project)

    assert_nil HackProject.find_by(id: project.id)
    assert PlanItem.find_by(user: @alice, schedule_item: @hack_day).present?,
           "Alice's PlanItem should survive the admin delete"
  end
end
