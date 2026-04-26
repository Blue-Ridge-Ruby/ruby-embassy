module ApplicationHelper
  # Renders a column header that links to the same page with ?sort=<key> applied.
  # Preserves any existing ?q= search term. The active sort gets a small arrow.
  def sort_link(label, key)
    active = @sort.to_s == key.to_s
    text   = active ? "#{label} ▾" : label
    params = { sort: key }
    params[:q] = @query if @query.present?
    href = "#{request.path}?#{params.to_query}"
    link_to text, href, class: active ? "sort-active" : nil
  end

  # Renders a schedule item's location as a link to its map URL when one is
  # set, otherwise as plain text. Returns nil when the item has no location.
  def location_or_map_link(item)
    return nil if item.location.blank?
    if item.map_url.present?
      link_to item.location, item.map_url,
              target: "_blank",
              rel:    "noopener noreferrer"
    else
      item.location
    end
  end
end
