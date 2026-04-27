class AdminController < ApplicationController
  skip_before_action :authenticate_user!
  before_action :require_admin!

  layout "admin"

  private

  # Reads params[:sort] and params[:dir], validates them against `columns`
  # (a hash of "key" => "comma,separated,column,exprs"), and returns an
  # ORDER BY clause string. Sets @sort and @dir for the view's sort_link
  # helper. Returns nil when params are absent or invalid — caller falls
  # back to its own default order.
  def apply_sort(columns)
    sort = columns.key?(params[:sort]) ? params[:sort] : nil
    dir  = %w[asc desc].include?(params[:dir]) ? params[:dir] : nil

    if sort && dir
      @sort = sort
      @dir  = dir
      columns[@sort].split(",").map { |c| "#{c.strip} #{@dir.upcase} NULLS LAST" }.join(", ")
    else
      @sort = nil
      @dir  = nil
      nil
    end
  end
end
