class UserMailer < ApplicationMailer
  def login_link(user)
    @user = user
    @token = user.generate_token_for(:login)
    @login_url = callback_session_url(token: @token)

    mail to: user.email, subject: "Your Ruby Embassy login link"
  end
end
