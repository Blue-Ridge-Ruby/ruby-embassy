require "test_helper"

class Admin::HackProjectsControllerTest < ActionDispatch::IntegrationTest
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
    @admin = users(:jeremy)
    @alice = users(:attendee_one)
    @vic   = users(:volunteer_one)
  end

  test "non-admin gets 404 on admin index" do
    sign_in_as @alice
    get admin_hack_projects_path
    assert_response :not_found
  end

  test "admin index lists all projects" do
    HackProject.create!(
      schedule_item: @hack_day, host: @alice,
      title: "Alpha project", repo_url: "https://github.com/x/a"
    )
    HackProject.create!(
      schedule_item: @hack_day, host: @vic,
      title: "Beta project", repo_url: "https://github.com/x/v"
    )

    sign_in_as @admin
    get admin_hack_projects_path

    assert_response :success
    assert_match "Alpha project", @response.body
    assert_match "Beta project", @response.body
    assert_match "Add Project", @response.body
  end

  test "admin creates a project on behalf of a user" do
    sign_in_as @admin
    assert_difference -> { HackProject.count } => 1,
                      -> { HackProjectSignup.count } => 1 do
      post admin_hack_projects_path,
           params: { hack_project: {
             host_id: @alice.id,
             host_role: "mentor",
             title: "Admin-created",
             repo_url: "https://github.com/x/admin"
           } }
    end

    project = HackProject.last
    assert_equal @alice, project.host
    assert project.hack_project_signups.find_by(user: @alice).mentor?
    assert_redirected_to admin_hack_projects_path
  end

  test "admin cannot create a project for a user already hosting" do
    HackProject.create!(
      schedule_item: @hack_day, host: @alice,
      title: "First", repo_url: "https://github.com/x/first"
    )

    sign_in_as @admin
    assert_no_difference -> { HackProject.count } do
      post admin_hack_projects_path,
           params: { hack_project: {
             host_id: @alice.id,
             host_role: "mentor",
             title: "Second", repo_url: "https://github.com/x/second"
           } }
    end
    assert_response :unprocessable_content
  end

  test "admin edits a project" do
    project = HackProject.create!(
      schedule_item: @hack_day, host: @alice,
      title: "Original", repo_url: "https://github.com/x/y"
    )

    sign_in_as @admin
    patch admin_hack_project_path(project),
          params: { hack_project: { title: "Updated by admin" } }

    assert_redirected_to admin_hack_projects_path
    assert_equal "Updated by admin", project.reload.title
  end

  test "admin deletes a project; signups cascade but PlanItems persist" do
    project = HackProject.create!(
      schedule_item: @hack_day, host: @alice,
      title: "Doomed", repo_url: "https://github.com/x/y"
    )
    project.hack_project_signups.create!(user: @alice, schedule_item: @hack_day, role: :mentor)
    project.hack_project_signups.create!(user: @vic, schedule_item: @hack_day, role: :mentee)

    sign_in_as @admin
    assert_difference -> { HackProject.count } => -1,
                      -> { HackProjectSignup.count } => -2,
                      -> { PlanItem.where(schedule_item: @hack_day).count } => 0 do
      delete admin_hack_project_path(project)
    end
    assert_redirected_to admin_hack_projects_path
  end

  test "admin show renders mentor and mentee lists" do
    project = HackProject.create!(
      schedule_item: @hack_day, host: @alice,
      title: "Showable", repo_url: "https://github.com/x/y"
    )
    project.hack_project_signups.create!(user: @alice, schedule_item: @hack_day, role: :mentor)
    project.hack_project_signups.create!(user: @vic, schedule_item: @hack_day, role: :mentee)

    sign_in_as @admin
    get admin_hack_project_path(project)

    assert_response :success
    assert_match "Mentors (1)", @response.body
    assert_match "Mentees (1)", @response.body
    assert_match @alice.full_name, @response.body
    assert_match @vic.full_name, @response.body
  end
end
