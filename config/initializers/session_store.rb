Rails.application.config.session_store :cookie_store,
  key: "_ruby_embassy_session",
  expire_after: 1.year,
  same_site: :lax
