require "prawn"

Prawn::Fonts::AFM.hide_m17n_warning = true

# Builds the official Ruby Embassy passport application PDF.
#
# Aesthetic: as formal as a US tax form. No logo. Serif type, fine rules,
# OMB-style form code, single-column dense layout, "FOR OFFICIAL EMBASSY
# USE ONLY" stamp area.
#
# Renders 2 pages per application:
#   1. Sections 1–5 of the application + applicant signature line
#   2. Notary certification with description, single follow-up, sig lines
#
# Pass `application: nil` plus `count: N` to render `N` blank applications
# in a single document (used by the admin blank-pdf generator).
class PassportApplicationPdf
  FORM_CODE  = "Form RE-1 (Rev. 2026-04)".freeze
  PAGE_SIZE  = "LETTER".freeze
  MARGIN     = 54 # 0.75 inch

  def initialize(application: nil, count: 1)
    @application = application
    @count = count
  end

  def render
    pdf = Prawn::Document.new(page_size: PAGE_SIZE, margin: MARGIN)
    pdf.font_families.update(
      "Times" => {
        normal: "Times-Roman", bold: "Times-Bold",
        italic: "Times-Italic", bold_italic: "Times-BoldItalic"
      }
    )
    pdf.font "Times"
    pdf.default_leading 1

    if @application
      render_application(pdf, @application)
    else
      @count.times do |i|
        render_application(pdf, nil)
        pdf.start_new_page if i < @count - 1
      end
    end

    pdf.render
  end

  private

  def render_application(pdf, application)
    @questions_index = build_questions_index
    render_page_one(pdf, application)
    pdf.start_new_page
    render_page_two(pdf, application)
  end

  # ------------------------------------------------------------------ Page 1

  def render_page_one(pdf, application)
    render_header(pdf, application, page_label: "Page 1 of 2")

    pdf.move_down 8
    render_section(pdf, application, 1, "DECLARATION OF RUBY-NESS")
    render_section(pdf, application, 2, "STATEMENT OF INTENT & CHARACTER")
    render_section(pdf, application, 3, "SUPPLEMENTARY DECLARATIONS", drawn: true)
    render_section(pdf, application, 4, "ATTESTATION OF COMMUNITY STANDING")
    render_section(pdf, application, 5, "AFFIDAVIT OF ATTENDANCE")
    render_signature_block(pdf, application)

    render_footer(pdf, application, page_label: "Page 1 of 2")
  end

  # ------------------------------------------------------------------ Page 2

  def render_page_two(pdf, application)
    render_header(pdf, application, page_label: "Page 2 of 2", title: "NOTARY CERTIFICATION ADDENDUM")

    pdf.move_down 12
    pdf.text "PART A — NOTARY DESIGNATION", size: 9, style: :bold
    pdf.stroke_horizontal_rule
    pdf.move_down 6

    pdf.text <<~PREAMBLE.strip, size: 9, leading: 2
      The Applicant must locate, in person and on Embassy premises, an attendee whose
      circumstances match the description set forth in Box A.1 below. The Applicant
      shall present this form to said attendee, who shall thereafter act as Notary
      and complete Part B in the Applicant's presence.
    PREAMBLE

    pdf.move_down 10
    pdf.text "A.1  The Notary must be an attendee who:", size: 9, style: :bold
    pdf.move_down 4
    notary = application&.notary_profile
    boxed_text(pdf, notary&.description, height: 36)

    pdf.move_down 14
    pdf.text "PART B — NOTARY ATTESTATION", size: 9, style: :bold
    pdf.stroke_horizontal_rule
    pdf.move_down 6

    pdf.text "B.1  Notary's response to the following inquiry:", size: 9, style: :bold
    pdf.move_down 2
    pdf.text notary&.followup_prompt.to_s, size: 9, style: :italic
    pdf.move_down 4
    boxed_text(pdf, nil, height: 60)

    pdf.move_down 14
    pdf.text "B.2  Certification by the Notary", size: 9, style: :bold
    pdf.move_down 4
    pdf.text "I certify that the Applicant has appeared before me and has answered "       \
             "the inquiry set forth in B.1 truthfully and to the best of their ability.",
             size: 9, leading: 2

    pdf.move_down 18
    sig_field(pdf, "Notary's printed name", width: 240)
    pdf.move_up 28
    pdf.bounding_box([260, pdf.cursor + 28], width: 220) do
      sig_field(pdf, "Date", width: 220)
    end

    pdf.move_down 8
    sig_field(pdf, "Notary's signature", width: 240)

    pdf.move_down 18
    pdf.text "FOR OFFICIAL EMBASSY USE ONLY", size: 8, style: :bold, align: :center
    pdf.stroke_rectangle [pdf.bounds.left, pdf.cursor - 6], pdf.bounds.width, 60
    pdf.move_down 70

    render_footer(pdf, application, page_label: "Page 2 of 2")
  end

  # ---------------------------------------------------------------- Sections

  def render_section(pdf, application, section_number, title, drawn: false)
    pdf.move_down 10
    pdf.text "SECTION #{section_number} — #{title}", size: 10, style: :bold
    pdf.stroke_horizontal_rule
    pdf.move_down 6

    questions = section_questions(application, section_number, drawn: drawn)
    return if questions.empty?

    questions.each_with_index do |question, idx|
      render_question(pdf, application, question, "#{section_number}.#{idx + 1}")
    end
  end

  def render_question(pdf, application, question, item_label)
    answer = application&.answer_for(question)

    pdf.move_down 6
    pdf.text "#{item_label}  #{question.label}", size: 9, style: :bold
    pdf.text question.help, size: 8, style: :italic, color: "555555" if question.help.present?

    pdf.move_down 4

    case question.field_type
    when "short", "select", "date"
      boxed_text(pdf, answer&.display_value.to_s, height: 18)
    when "long"
      boxed_text(pdf, answer&.display_value.to_s, height: 48)
    when "checkbox"
      checked = answer&.display_value == true
      pdf.formatted_text [
        { text: checked ? "[X] " : "[ ] ", styles: [:bold] },
        { text: "I affirm.", size: 9 }
      ]
    when "checkbox_group"
      selected = Array(answer&.display_value)
      question.options.each do |opt|
        pdf.formatted_text [
          { text: selected.include?(opt) ? "[X] " : "[ ] ", styles: [:bold] },
          { text: opt, size: 9 }
        ]
      end
    end
  end

  def section_questions(application, section_number, drawn:)
    if drawn
      application ? application.drawn_questions.to_a : []
    else
      Question.active.for_section(section_number).to_a
    end
  end

  # --------------------------------------------------------- Header / Footer

  def render_header(pdf, application, page_label:, title: "RUBY EMBASSY · APPLICATION FOR PASSPORT")
    pdf.font_size 9
    pdf.text FORM_CODE, align: :right, style: :bold
    pdf.move_down 2
    pdf.text title, size: 14, style: :bold, align: :center
    pdf.text "United Embassy of Ruby · Asheville, NC", size: 9, align: :center, style: :italic
    pdf.move_down 4
    pdf.stroke_horizontal_rule
    pdf.move_down 4

    serial = application&.serial || "[BLANK]"
    submitted = application&.submitted_at&.strftime("%B %-d, %Y · %-l:%M %p") || "—"
    booking = application&.embassy_booking
    schedule_item = booking&.schedule_item
    when_text = schedule_item ? "#{ScheduleItem::DAY_META.dig(schedule_item.day, :date)} · #{schedule_item.time_label}" : "—"
    applicant = booking&.user&.full_name || "—"

    metadata_row(pdf, [
      ["Serial No.",    serial],
      ["Appointment",   when_text],
      ["Applicant",     applicant],
      ["Submitted",     submitted],
    ])
    pdf.move_down 6
    pdf.stroke_horizontal_rule
  end

  def metadata_row(pdf, pairs)
    col_width = (pdf.bounds.width / pairs.length.to_f).floor
    pdf.bounding_box([0, pdf.cursor], width: pdf.bounds.width, height: 26) do
      pairs.each_with_index do |(label, value), i|
        pdf.bounding_box([i * col_width, pdf.bounds.top], width: col_width, height: 26) do
          pdf.text label, size: 7, style: :bold, color: "555555"
          pdf.text value.to_s, size: 9
        end
      end
    end
  end

  def render_footer(pdf, application, page_label:)
    pdf.repeat(:all) do
      pdf.bounding_box([0, 30], width: pdf.bounds.width) do
        serial = application&.serial || "[BLANK]"
        pdf.stroke_horizontal_rule
        pdf.move_down 2
        pdf.font_size 7
        pdf.formatted_text_box [
          { text: "Form RE-1 · Serial #{serial}", styles: [:italic] },
          { text: "    ·    ", color: "999999" },
          { text: page_label }
        ], at: [0, pdf.cursor], width: pdf.bounds.width, align: :center, size: 7
      end
    end
  end

  # ------------------------------------------------------------ Signature

  def render_signature_block(pdf, application)
    pdf.move_down 14
    pdf.text "APPLICANT SIGNATURE", size: 9, style: :bold
    pdf.stroke_horizontal_rule
    pdf.move_down 8

    signed_name = application&.embassy_application_answers
      &.joins(:question)&.where(questions: { external_id: "5d" })
      &.first&.value_text
    sig_field(pdf, "Signature of Applicant (typed)", width: 280, value: signed_name)

    pdf.move_up 28
    pdf.bounding_box([300, pdf.cursor + 28], width: 200) do
      submitted_on = application&.submitted_at&.strftime("%Y-%m-%d") || ""
      sig_field(pdf, "Date executed", width: 200, value: submitted_on)
    end

    pdf.move_down 8
  end

  # --------------------------------------------------------- Drawing helpers

  def boxed_text(pdf, text, height:)
    width = pdf.bounds.right - pdf.bounds.left
    top   = pdf.cursor
    pdf.stroke do
      pdf.line_width 0.5
      pdf.rectangle [0, top], width, height
    end
    if text.to_s.strip.length.positive?
      pdf.bounding_box([6, top - 4], width: width - 12, height: height - 6) do
        pdf.text text.to_s, size: 9, overflow: :shrink_to_fit
      end
    end
    pdf.move_cursor_to(top - height - 2)
  end

  def sig_field(pdf, caption, width:, value: nil)
    top = pdf.cursor
    pdf.line_width 0.6
    pdf.stroke_line [0, top - 14], [width, top - 14]
    if value.present?
      pdf.bounding_box([2, top], width: width - 4, height: 14) do
        pdf.text value.to_s, size: 9
      end
    end
    pdf.move_down 16
    pdf.text caption, size: 7, color: "555555"
  end

  def build_questions_index
    @questions_index ||= Question.active.includes(:embassy_application_answers).index_by(&:id)
  end
end
