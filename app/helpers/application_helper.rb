module ApplicationHelper
  # Renders a column header that cycles through three sort states on click:
  # inactive → asc → desc → inactive (back to the page's default order).
  # Preserves any existing ?q= search term. Active column shows ▲ for asc, ▼ for desc.
  def sort_link(label, key)
    key    = key.to_s
    active = @sort.to_s == key

    next_sort, next_dir, arrow =
      if !active
        [ key, "asc", "" ]
      elsif @dir.to_s == "asc"
        [ key, "desc", " ▲" ]
      else
        [ nil, nil, " ▼" ]
      end

    params = {}
    params[:sort] = next_sort if next_sort
    params[:dir]  = next_dir  if next_dir
    params[:q]    = @query    if @query.present?

    href = params.empty? ? request.path : "#{request.path}?#{params.to_query}"
    link_to "#{label}#{arrow}", href, class: active ? "sort-active" : nil
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

  # Renders a talk's host as a link to their blueridgeruby.com speaker page
  # when host_url is set, otherwise as plain text. Returns nil if no host.
  def speaker_link(item)
    return nil if item.host.blank?
    if item.host_url.present?
      link_to item.host, item.host_url,
              target: "_blank",
              rel:    "noopener noreferrer"
    else
      item.host
    end
  end
end
