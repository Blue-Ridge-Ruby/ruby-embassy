module Admin
  class UsersController < AdminController
    SORTS = {
      "name"       => "users.last_name ASC, users.first_name ASC",
      "email"      => "users.email ASC",
      "role"       => "users.role ASC",
      "last_login" => "users.last_sign_in_at DESC NULLS LAST"
    }.freeze

    def index
      @sort  = SORTS.key?(params[:sort]) ? params[:sort] : "name"
      @query = params[:q].to_s.strip
      @users = filtered_users.reorder(Arel.sql(SORTS[@sort]))
    end

    def show
      @user = User.find(params[:id])

      all_plan_items = @user.plan_items
                            .includes(:schedule_item)
                            .sort_by { |pi|
                              [
                                ScheduleItem::DAY_META.keys.index(pi.schedule_item.day) || 99,
                                pi.schedule_item.sort_time.to_i
                              ]
                            }
      @embassy_plan_items = all_plan_items.select { |pi| pi.schedule_item.embassy? }
      @other_plan_items   = all_plan_items - @embassy_plan_items

      # "Hosting" = any schedule_item whose host string matches this user's
      # full_name. Catches both admin-dropdown assignments and user-created
      # custom blocks (the user-facing controller auto-sets host to
      # current_user.full_name on create).
      @hosted_items = ScheduleItem.where(host: @user.full_name).ordered
    end

    def new
      @user = User.new
    end

    def create
      @user = User.new(user_params)

      if @user.save(context: :interactive)
        redirect_to admin_users_path, notice: "User added."
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit
      @user = User.find(params[:id])
    end

    def update
      @user = User.find(params[:id])
      @user.assign_attributes(user_params)

      if @user.save(context: :interactive)
        redirect_to admin_users_path, notice: "User updated."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      User.find(params[:id]).destroy
      redirect_to admin_users_path, notice: "User removed."
    end

    def sync
      users = User.all.to_a
      slugs  = users.each_with_object({}) { |u, h| h[u.tito_ticket_slug] = u if u.tito_ticket_slug.present? }
      emails = users.each_with_object({}) { |u, h| (h[u.email.downcase] ||= u) if u.email.present? && u.tito_ticket_slug.blank? }

      already = 0
      connected = 0
      added = 0

      User.tito_client.tickets.where(state: %w[complete]).each do |ticket|
        if slugs[ticket.slug]
          already += 1
        elsif (user = emails[ticket.email.to_s.downcase])
          user.update!(
            tito_ticket_slug: ticket.slug,
            first_name: ticket.first_name,
            last_name: ticket.last_name
          )
          connected += 1
        else
          User.create!(
            tito_ticket_slug: ticket.slug,
            first_name: ticket.first_name,
            last_name: ticket.last_name,
            email: ticket.email,
            role: :attendee
          )
          added += 1
        end
      end

      redirect_to admin_users_path,
        notice: "Sync complete: #{already} already linked, #{connected} connected, #{added} added."
    rescue StandardError => e
      Rails.logger.error("Tito sync error: #{e.class}: #{e.message}")
      redirect_to admin_users_path,
        alert: "Sync failed: #{e.message}. Check your Tito configuration."
    end

    private

    def filtered_users
      scope = User.all
      return scope if @query.blank?

      term = "%#{@query}%"
      scope.where(
        "first_name ILIKE :t OR last_name ILIKE :t OR email ILIKE :t",
        t: term
      )
    end

    def user_params
      params.require(:user).permit(:first_name, :last_name, :email, :role)
    end
  end
end
