class ApplicationController < ActionController::Base
  allow_browser versions: :modern
  stale_when_importmap_changes

  before_action :authenticate_user!
  before_action :touch_last_seen

  helper_method :current_user, :admin?

  private

  def current_user
    return @current_user if defined?(@current_user)
    @current_user = session[:user_id] && User.find_by(id: session[:user_id])
  end

  def admin?
    current_user&.admin?
  end

  def authenticate_user!
    unless current_user
      session[:return_to] = request.url if request.get?
      redirect_to new_session_path, alert: "Please sign in."
    end
  end

  def touch_last_seen
    return unless current_user
    return if current_user.last_seen_at && current_user.last_seen_at > 5.minutes.ago
    current_user.update_columns(last_seen_at: Time.current)
  end

  def require_admin!
    raise ActiveRecord::RecordNotFound unless current_user&.admin?
  end
end
