require "prawn"
require "prawn/table"

Prawn::Fonts::AFM.hide_m17n_warning = true

# A printable lineup for the day-of admin: title, day/time, and a
# numbered speaker list with slot times and talk titles.
class LightningTalksPdf
  PAGE_SIZE = "LETTER".freeze
  MARGIN    = 50

  def initialize(schedule_item)
    @schedule_item = schedule_item
    @signups       = schedule_item.lightning_talk_signups.includes(:user).ordered
  end

  def render
    pdf = Prawn::Document.new(page_size: PAGE_SIZE, margin: MARGIN)
    pdf.font "Helvetica"

    pdf.font_size 20
    pdf.text "Lightning Talks Lineup", style: :bold

    pdf.move_down 4
    pdf.font_size 11
    pdf.fill_color "555555"
    day_label = ScheduleItem::DAY_META.dig(@schedule_item.day, :label) || @schedule_item.day
    pdf.text "#{day_label}  ·  #{@schedule_item.time_label}  ·  #{@signups.size} of #{LightningTalkSignup::MAX_SPEAKERS} speakers"
    pdf.fill_color "000000"

    pdf.move_down 18

    if @signups.empty?
      pdf.font_size 11
      pdf.text "No speakers signed up yet.", style: :italic, color: "777777"
    else
      data = [ [ "#", "Time", "Speaker", "Talk title" ] ]
      @signups.each do |signup|
        data << [
          signup.position.to_s,
          signup.slot_start_label,
          signup.user.full_name,
          signup.talk_title.to_s
        ]
      end

      pdf.table(data, header: true, width: pdf.bounds.width) do
        row(0).font_style       = :bold
        row(0).background_color = "EEEEEE"
        cells.borders           = [ :bottom ]
        cells.padding           = [ 6, 8 ]
        column(0).width         = 30
        column(1).width         = 70
        column(2).width         = 160
      end
    end

    pdf.render
  end
end
