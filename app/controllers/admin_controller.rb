class AdminController < ApplicationController
  skip_before_action :authenticate_user!
  before_action :require_admin!

  layout "admin"
end
