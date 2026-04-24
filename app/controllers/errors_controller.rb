class ErrorsController < ApplicationController
  # Error pages are reachable anonymously — the app-wide
  # authenticate_user! filter would otherwise redirect to sign-in.
  skip_before_action :authenticate_user!

  def not_found
    render :not_found, status: :not_found
  end

  def unprocessable_content
    render :unprocessable_content, status: :unprocessable_content
  end

  def internal_server_error
    render :internal_server_error, status: :internal_server_error
  end
end
