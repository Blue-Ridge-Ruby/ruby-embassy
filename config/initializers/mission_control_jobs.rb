Rails.application.config.to_prepare do
  MissionControl::Jobs.base_controller_class = "AdminController"
  MissionControl::Jobs.http_basic_auth_enabled = false
end
