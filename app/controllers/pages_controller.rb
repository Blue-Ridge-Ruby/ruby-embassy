class PagesController < ApplicationController
  def home
    redirect_to schedule_path
  end
end
