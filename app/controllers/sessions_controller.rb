class SessionsController < ApplicationController
  skip_before_action :authenticate_user!, only: %i[new create callback]

  REGISTER_URL = "https://blueridgeruby.com/#register".freeze

  def new
  end

  def create
    @email = params[:email].to_s.strip.downcase
    user = User.where("LOWER(email) = ?", @email).first

    if user.nil?
      result = TitoLookupService.new.find_or_create_from_tito(@email)
      case result.status
      when :found
        user = result.user
      when :not_found
        @register_url = REGISTER_URL
        render :not_registered, status: :not_found
        return
      when :api_error
        flash.now[:alert] = "Something went wrong checking your registration. Please try again in a few minutes."
        render :new, status: :service_unavailable
        return
      end
    end

    UserMailer.login_link(user).deliver_later
    redirect_to new_session_path, notice: "Check your email for a login link."
  end

  def callback
    @token = params[:token]

    if request.post?
      user = User.find_by_token_for(:login, @token)

      if user
        session[:user_id] = user.id
        user.update_columns(last_sign_in_at: Time.current)
        redirect_to(session.delete(:return_to) || dashboard_path, notice: "Signed in.")
      else
        redirect_to new_session_path, alert: "Invalid or expired login link."
      end
    end
  end

  def destroy
    session.delete(:user_id)
    redirect_to root_path, notice: "Signed out."
  end
end
