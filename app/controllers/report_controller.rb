class ReportController < ApplicationController
  skip_before_action :authenticate_user!

  def index
    @report = Rails.cache.fetch("annual_report:v1", expires_in: 1.hour) { AnnualReport.build }
  end
end
