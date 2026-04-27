module ScheduleHelper
  KIND_DISPLAY_OVERRIDES = { "lightning" => "⚡ Lightning Talks" }.freeze

  def kind_display_label(kind)
    return nil if kind.blank?
    KIND_DISPLAY_OVERRIDES[kind.to_s] || kind.to_s.humanize
  end

  def visible_filter_kinds(user)
    ScheduleItem.kinds.keys.reject do |kind|
      kind == "reception" ||
        (kind == "volunteer" && !(user&.volunteer? || user&.admin?))
    end.sort_by { |kind| kind_display_label(kind) }
  end
end
