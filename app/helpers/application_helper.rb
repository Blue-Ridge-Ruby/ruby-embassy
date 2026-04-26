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
end
