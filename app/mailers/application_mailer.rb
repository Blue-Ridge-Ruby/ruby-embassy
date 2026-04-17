class ApplicationMailer < ActionMailer::Base
  include Configuration::Configurable

  configure_with from: :email_from
  default from: from

  layout "mailer"
end
