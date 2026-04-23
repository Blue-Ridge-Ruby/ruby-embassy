class TitoLookupService
  Result = Data.define(:status, :user)

  def find_or_create_from_tito(email)
    normalized = email.to_s.strip.downcase
    return Result.new(status: :not_found, user: nil) if normalized.blank?

    ticket = User.tito_client.tickets
                 .where(state: %w[complete])
                 .detect { |t| t.email.to_s.downcase == normalized }

    return Result.new(status: :not_found, user: nil) unless ticket

    user = User.create!(
      email: ticket.email,
      first_name: ticket.first_name,
      last_name: ticket.last_name,
      tito_ticket_slug: ticket.slug,
      role: :attendee
    )
    Result.new(status: :found, user: user)
  rescue StandardError => e
    Rails.logger.error("TitoLookupService error for #{email.inspect}: #{e.class}: #{e.message}")
    Result.new(status: :api_error, user: nil)
  end
end
