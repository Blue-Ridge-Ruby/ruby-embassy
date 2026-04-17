module Admin
  class UsersController < AdminController
    def index
      @users = User.order(:last_name, :first_name)
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

    def user_params
      params.require(:user).permit(:first_name, :last_name, :email, :role)
    end
  end
end
