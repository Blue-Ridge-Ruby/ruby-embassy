module MealSpotsHelper
  def meal_spot_attendee_name(user)
    return "Someone" if user.nil?
    user.first_name.presence || user.email.to_s.split("@").first
  end

  # Seed the new-transport datetime picker with the meal's actual start time
  # (sort_time is an HHMM integer — 1200 = 12:00, 1730 = 17:30) on the meal's
  # day. Adjusting from the meal time is way faster than dragging a 6:30 PM
  # default down to noon.
  def default_departure(meal)
    base_date = ScheduleItem::DAY_META.dig(meal.day, :date)
    return nil if base_date.blank? || meal.sort_time.blank?
    hours   = meal.sort_time / 100
    minutes = meal.sort_time % 100
    Time.zone.parse("#{base_date} 2026 #{hours}:#{format('%02d', minutes)}") rescue nil
  end
end
