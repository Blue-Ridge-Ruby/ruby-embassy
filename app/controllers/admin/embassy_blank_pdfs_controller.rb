class Admin::EmbassyBlankPdfsController < AdminController
  def new
    @default_count = 12
  end

  def create
    count = (params[:count].presence || 12).to_i.clamp(1, 100)

    send_data PassportApplicationPdf.new(application: nil, count: count).render,
              filename: "ruby-embassy-blank-applications-#{count}.pdf",
              type: "application/pdf",
              disposition: "attachment"
  end
end
