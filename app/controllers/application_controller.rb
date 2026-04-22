class ApplicationController < ActionController::Base
  allow_browser versions: :modern
  stale_when_importmap_changes

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

  def require_admin!
    authenticate_user!
    return if performed?

    unless admin?
      redirect_to dashboard_path, alert: "Admins only."
    end
  end
end
