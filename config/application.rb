require_relative "boot"

require "rails/all"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module RubyEmbassy
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 8.1

    # Please, add to the `ignore` list any other `lib` subdirectories that do
    # not contain `.rb` files, or that should not be reloaded or eager loaded.
    # Common ones are `templates`, `generators`, or `middleware`, for example.
    config.autoload_lib(ignore: %w[assets tasks])

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    # config.time_zone = "Central Time (US & Canada)"
    # config.eager_load_paths << Rails.root.join("extras")
    MissionControl::Jobs.http_basic_auth_user = ENV["MISSION_CONTROL_USER"]
    MissionControl::Jobs.http_basic_auth_password = ENV["MISSION_CONTROL_PASSWORD"]

    # Render branded error pages via routes -> ErrorsController. Uses the
    # regular application layout so the nav + footer + fonts match the
    # rest of the app. public/*.html were removed so direct browser hits
    # to /404 also route through Rails instead of hitting ActionDispatch::Static.
    config.exceptions_app = self.routes
  end
end
