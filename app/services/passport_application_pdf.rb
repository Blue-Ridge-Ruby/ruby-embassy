require "prawn"

Prawn::Fonts::AFM.hide_m17n_warning = true

# Builds the official Ruby Embassy passport application PDF.
#
# Aesthetic: as formal as a US tax form. No logo, no flourishes.
# Helvetica throughout (built-in, broad UTF-8). Fine 0.5pt rules,
# OMB-style form code in the top-right, "FOR OFFICIAL EMBASSY USE ONLY"
# stamp area on the notary page, page numbering in the bottom margin.
#
# Layout: short-form questions (short / select / date / checkbox) flow
# in two columns; long-form questions (long / checkbox_group) span the
# full width. Box heights for long answers scale with the question's
# max_length so longer answers get more vertical room.
#
# Renders 2 pages per application:
#   1. Sections 1-5 + applicant signature block
#   2. Notary certification (designation, attestation, sigs)
#
# For blank-batch printing, pass `application: nil, count: N` to render
# N applications back-to-back in one document.
class PassportApplicationPdf
  FORM_CODE         = "Form RE-1 (Rev. 2026-04)".freeze
  PAGE_SIZE         = "LETTER".freeze
  MARGIN            = 36
  LONG_LINE_HEIGHT  = 9.5
  LONG_BOX_PADDING  = 6
  LONG_BOX_MIN      = 22
  LONG_BOX_MAX      = 38

  def initialize(application: nil, count: 1)
    @application = application
    @count       = count
  end

  def render
    pdf = Prawn::Document.new(page_size: PAGE_SIZE, margin: MARGIN)
    pdf.font "Helvetica"
    pdf.default_leading 1

    if @application
      render_application(pdf, @application)
    else
      @count.times do |i|
        render_application(pdf, nil)
        pdf.start_new_page if i < @count - 1
      end
    end

    paginate(pdf)
    pdf.render
  end

  private

  # ============================================================ orchestration

  def render_application(pdf, application)
    render_page_one(pdf, application)
    pdf.start_new_page
    render_page_two(pdf, application)
  end

  # ================================================================== page 1

  def render_page_one(pdf, application)
    render_header(pdf, application)
    render_section(pdf, application, 1, "DECLARATION OF RUBY-NESS")
    render_section(pdf, application, 2, "STATEMENT OF INTENT & CHARACTER")
    render_section(pdf, application, 3, "SUPPLEMENTARY DECLARATIONS", drawn: true)
    render_section(pdf, application, 4, "ATTESTATION OF COMMUNITY STANDING")
    render_section(pdf, application, 5, "AFFIDAVIT OF ATTENDANCE")
    render_signature_block(pdf, application)
    render_instructions(pdf)
  end

  # ================================================================== page 2

  def render_page_two(pdf, application)
    render_header(pdf, application, title: "NOTARY CERTIFICATION ADDENDUM")

    pdf.move_down 10
    pdf.text "PART A — NOTARY DESIGNATION", size: 9, style: :bold
    pdf.stroke_horizontal_rule
    pdf.move_down 6

    pdf.text <<~PREAMBLE.strip, size: 8.5, leading: 2
      The Applicant must locate, in person and on Embassy premises, an attendee whose
      circumstances match the description set forth in Box A.1 below. The Applicant
      shall present this form to said attendee, who shall thereafter act as Notary
      and complete Part B in the Applicant's presence.
    PREAMBLE

    pdf.move_down 10
    pdf.text "A.1  The Notary must be an attendee who:", size: 9, style: :bold
    pdf.move_down 4
    notary = application&.notary_profile
    boxed_text(pdf, notary&.description, height: 32)

    pdf.move_down 14
    pdf.text "PART B — NOTARY ATTESTATION", size: 9, style: :bold
    pdf.stroke_horizontal_rule
    pdf.move_down 6

    pdf.text "B.1  Notary's response to the following inquiry:", size: 9, style: :bold
    pdf.move_down 2
    pdf.text(notary&.followup_prompt.to_s, size: 9, style: :italic) if notary&.followup_prompt
    pdf.move_down 4
    boxed_text(pdf, nil, height: 56)

    pdf.move_down 14
    pdf.text "B.2  Certification by the Notary", size: 9, style: :bold
    pdf.move_down 4
    pdf.text "I certify that the Applicant has appeared before me and has answered "       \
             "the inquiry set forth in B.1 truthfully and to the best of their ability.",
             size: 8.5, leading: 2

    pdf.move_down 18
    two_column_signatures(pdf, [
      ["Notary's printed name", nil],
      ["Date executed",         nil]
    ])
    pdf.move_down 12
    two_column_signatures(pdf, [
      ["Notary's signature", nil],
      ["Notary ID (assigned)", notary&.external_id]
    ])

    pdf.move_down 24
    pdf.text "FOR OFFICIAL EMBASSY USE ONLY", size: 8, style: :bold, align: :center
    pdf.stroke do
      pdf.line_width 0.5
      pdf.rectangle [pdf.bounds.left, pdf.cursor - 4], pdf.bounds.width, 56
    end
    pdf.move_down 60
  end

  # ================================================================ sections

  # Rough lower bound to keep a section title from being orphaned at the bottom
  # of a page with no questions following it.
  MIN_SECTION_REMAINDER = 80

  def render_section(pdf, application, section_number, title, drawn: false)
    pdf.start_new_page if pdf.cursor < MIN_SECTION_REMAINDER

    pdf.move_down 5
    pdf.text "SECTION #{section_number}  ·  #{title}", size: 8.5, style: :bold
    pdf.stroke_horizontal_rule
    pdf.move_down 2

    questions = section_questions(application, section_number, drawn: drawn)
    return if questions.empty?

    flow_questions(pdf, application, questions, section_number)
  end

  # Lays questions out in two columns where they fit, full-width otherwise.
  # Iterates in question order; pairs adjacent half-width questions into rows.
  def flow_questions(pdf, application, questions, section_number)
    pending = nil
    questions.each_with_index do |q, idx|
      label = "#{section_number}.#{idx + 1}"
      if half_width?(q)
        if pending
          render_pair(pdf, application, pending[:q], pending[:label], q, label)
          pending = nil
        else
          pending = { q: q, label: label }
        end
      else
        if pending
          render_question(pdf, application, pending[:q], pending[:label], width: pdf.bounds.width)
          pending = nil
        end
        render_question(pdf, application, q, label, width: pdf.bounds.width)
      end
    end
    render_question(pdf, application, pending[:q], pending[:label], width: pdf.bounds.width) if pending
  end

  # short / select / date go side-by-side; everything else is full-width.
  def half_width?(question)
    %w[short select date].include?(question.field_type)
  end

  PAIRED_ROW_HEIGHT = 24 # label (8pt) + 1pt + 13pt box + 2pt buffer

  def render_pair(pdf, application, q1, label1, q2, label2)
    gutter = 12
    half   = (pdf.bounds.width - gutter) / 2.0
    y      = pdf.cursor

    pdf.bounding_box([0, y], width: half, height: PAIRED_ROW_HEIGHT) do
      render_question_in_box(pdf, application, q1, label1, width: half, height: PAIRED_ROW_HEIGHT)
    end
    pdf.bounding_box([half + gutter, y], width: half, height: PAIRED_ROW_HEIGHT) do
      render_question_in_box(pdf, application, q2, label2, width: half, height: PAIRED_ROW_HEIGHT)
    end
    pdf.move_cursor_to(y - PAIRED_ROW_HEIGHT - 2)
  end

  # Fixed-position rendering for a half-width question inside a pair row.
  # Uses text_box (constrains width, truncates) so long labels don't overflow.
  def render_question_in_box(pdf, application, question, item_label, width:, height:)
    answer = application&.answer_for(question)
    label_text = "#{item_label}  #{question.label}"

    pdf.text_box label_text, at: [0, height - 1], width: width, height: 9,
                 size: 7.5, style: :bold, overflow: :truncate

    box_top = height - 11
    box_h   = 13
    pdf.line_width 0.5
    pdf.stroke_rectangle [0, box_top], width, box_h

    value = answer&.display_value.to_s
    if value.length.positive?
      pdf.text_box value, at: [4, box_top - 2], width: width - 8, height: box_h - 4,
                   size: 7.5, overflow: :truncate
    end
  end

  # Returns the height it consumed. When advance is false, doesn't move cursor
  # afterward (caller is in a paired layout and manages cursor manually).
  def render_question(pdf, application, question, item_label, width:, advance: true)
    answer = application&.answer_for(question)
    start_y = pdf.cursor

    pdf.text "#{item_label}  #{question.label}", size: 7.5, style: :bold, leading: 0.5

    pdf.move_down 1

    case question.field_type
    when "short", "select", "date"
      boxed_text(pdf, answer&.display_value.to_s, height: 13, width: width)
    when "long"
      boxed_text(pdf, answer&.display_value.to_s, height: long_box_height(question, width), width: width)
    when "checkbox"
      checked = answer&.display_value == true
      pdf.formatted_text [
        { text: checked ? "[X] " : "[ ] ", styles: [:bold] },
        { text: "I affirm.", size: 7.5 }
      ]
    when "checkbox_group"
      render_checkbox_group(pdf, question, answer, width: width)
    end

    consumed = start_y - pdf.cursor
    pdf.move_down 2 if advance
    consumed + 2
  end

  # Checkbox group rendering — picks layout based on option length:
  #   - inline (formatted_text auto-wrap) for short options like "Vibes",
  #     "Networking" — packs 4-5 onto one line.
  #   - two-column grid for longer affirmations like Section 4's, where
  #     packing them inline reads as a messy run-on.
  def render_checkbox_group(pdf, question, answer, width:)
    selected = Array(answer&.display_value)
    options  = question.options
    return if options.empty?

    if two_column_options?(options)
      render_checkbox_group_grid(pdf, options, selected, width: width)
    else
      render_checkbox_group_inline(pdf, options, selected)
    end
  end

  def two_column_options?(options)
    options.size >= 6 || options.any? { |o| o.length > 30 }
  end

  def render_checkbox_group_inline(pdf, options, selected)
    fragments = options.flat_map do |opt|
      [
        { text: selected.include?(opt) ? "[X] " : "[ ] ", styles: [:bold] },
        { text: "#{opt}      " }
      ]
    end
    pdf.formatted_text fragments, size: 7.5, leading: 1
  end

  def render_checkbox_group_grid(pdf, options, selected, width:)
    col_width = (width - 8) / 2.0
    rows = (options.length / 2.0).ceil
    y = pdf.cursor
    rows.times do |row|
      [0, 1].each do |col|
        opt = options[row * 2 + col]
        next unless opt
        pdf.bounding_box([col * (col_width + 8), y - row * 10], width: col_width, height: 10) do
          pdf.formatted_text [
            { text: selected.include?(opt) ? "[X] " : "[ ] ", styles: [:bold] },
            { text: opt, size: 7.5 }
          ]
        end
      end
    end
    pdf.move_cursor_to(y - rows * 10 - 2)
  end

  def long_box_height(question, width)
    max_chars = question.max_length || 240
    chars_per_line = (width / 4.5).to_i.clamp(40, 100)
    lines = (max_chars.to_f / chars_per_line).ceil.clamp(2, 5)
    (lines * LONG_LINE_HEIGHT + LONG_BOX_PADDING).clamp(LONG_BOX_MIN, LONG_BOX_MAX)
  end

  def section_questions(application, section_number, drawn:)
    if drawn
      application ? application.drawn_questions.to_a : Question.random_pool_active.limit(EmbassyApplicationDraw::POOL_SIZE).to_a
    else
      Question.active.for_section(section_number).to_a
    end
  end

  # ================================================================== header

  def render_header(pdf, application, title: "RUBY EMBASSY · APPLICATION FOR PASSPORT")
    pdf.font_size 8
    pdf.text FORM_CODE, align: :right, style: :bold, size: 7
    pdf.text title, size: 11, style: :bold, align: :center
    pdf.text "Blue Ridge Ruby Embassy · Asheville, NC", size: 7.5, align: :center, style: :italic
    pdf.move_down 3
    pdf.stroke_horizontal_rule
    pdf.move_down 3

    serial      = application&.serial || "[BLANK]"
    booking     = application&.embassy_booking
    schedule    = booking&.schedule_item
    when_text   = schedule ? "#{ScheduleItem::DAY_META.dig(schedule.day, :date)} · #{schedule.time_label}" : "—"
    applicant   = booking&.user&.full_name || "—"
    submitted   = application&.submitted_at&.strftime("%b %-d, %Y · %-l:%M %p") || "—"

    metadata_row(pdf, [
      ["Serial No.",  serial],
      ["Appointment", when_text],
      ["Applicant",   applicant],
      ["Submitted",   submitted]
    ])
    pdf.move_down 2
    pdf.stroke_horizontal_rule
  end

  def metadata_row(pdf, pairs)
    col_width = (pdf.bounds.width / pairs.length.to_f).floor
    y = pdf.cursor
    pdf.bounding_box([0, y], width: pdf.bounds.width, height: 18) do
      pairs.each_with_index do |(label, value), i|
        pdf.bounding_box([i * col_width, pdf.bounds.top], width: col_width, height: 18) do
          pdf.text label.to_s, size: 6, style: :bold, color: "666666"
          pdf.text value.to_s, size: 8
        end
      end
    end
  end

  # =============================================================== signature

  INSTRUCTIONS = [
    [
      "INSTRUCTIONS TO THE APPLICANT",
      [
        "1. Print this form on standard letter-size paper. Both pages of the application and the Notary Certification Addendum must be presented at the Embassy.",
        "2. Section 3 is drawn from a rotating pool of supplementary declarations. The Applicant should answer the questions as printed; substitution is not permitted.",
        "3. The Notary in Part B of the Addendum must be located on Embassy premises and must affix their signature in the presence of the Embassy Attaché. Remote attestation is not recognized.",
        "4. Applicants are encouraged to arrive five (5) minutes before their appointment. Late arrivals may be accommodated at the Attaché's sole discretion."
      ]
    ],
    [
      "EMBASSY ORDINANCES (EXCERPTED)",
      [
        "§1.  Validity. This application shall remain valid for the duration of Blue Ridge Ruby 2026 and may not be transferred to any subsequent calendar year, conference, or commemorative gathering.",
        "§2.  Discretion. The Embassy reserves sole and absolute discretion to deny issuance for cause, including but not limited to: insufficient ceremony, ill-fitting suspenders, or a documented preference for tabs over spaces.",
        "§3.  Truthfulness. Falsified declarations may result in revocation of Ruby Embassy privileges for up to three (3) business gems and forfeiture of any commemorative stamps so obtained.",
        "§4.  Notary Conduct. The Applicant shall conduct themselves with reasonable courtesy toward the Notary. Bribery of the Notary is strictly prohibited unless said bribery consists of coffee, in which case discretion is advised.",
        "§5.  Right of Appeal. Applicants whose stamping is denied may request review by writing to /dev/null on Embassy stationery. Review proceedings, where granted, are conducted ex parte.",
        "§6.  Liability. The Embassy assumes no liability for stamping-related psychological distress, including but not limited to: imposter syndrome, premature optimization, or the realization that one has been pronouncing \"RubyGems\" wrong this entire time.",
        "§7.  Severability. Should any provision herein be deemed invalid by competent jurisdiction, the remaining provisions shall continue in full effect, possibly more so."
      ]
    ]
  ].freeze

  def render_instructions(pdf)
    return if pdf.cursor < 110 # not enough room for even a partial section

    INSTRUCTIONS.each do |title, paragraphs|
      break if pdf.cursor < 60

      pdf.move_down 16
      pdf.text title, size: 8, style: :bold
      pdf.stroke_horizontal_rule
      pdf.move_down 4

      paragraphs.each do |para|
        break if pdf.cursor < 24 # don't orphan a paragraph
        pdf.text para, size: 7, leading: 1.5, color: "333333"
        pdf.move_down 3
      end
    end
  end

  SIGNATURE_MIN_HEIGHT = 50

  def render_signature_block(pdf, application)
    pdf.start_new_page if pdf.cursor < SIGNATURE_MIN_HEIGHT

    pdf.move_down 6
    pdf.text "APPLICANT SIGNATURE", size: 8, style: :bold
    pdf.stroke_horizontal_rule
    pdf.move_down 4

    signed_name = answer_text(application, "5d")
    submitted_on = application&.submitted_at&.strftime("%Y-%m-%d") || ""

    two_column_signatures(pdf, [
      ["Signature of Applicant (typed)", signed_name],
      ["Date executed",                  submitted_on]
    ])
  end

  # Renders two captioned signature lines side-by-side in fixed-height boxes.
  # Each box: 20pt total. Value sits on top of the line, caption below.
  def two_column_signatures(pdf, pairs)
    gutter   = 24
    half     = (pdf.bounds.width - gutter) / 2.0
    y_top    = pdf.cursor
    box_h    = 24
    pairs.each_with_index do |(caption, value), i|
      x = i * (half + gutter)
      # bounding_box shifts cursor inside; draw value, line, caption at fixed offsets.
      pdf.bounding_box([x, y_top], width: half, height: box_h) do
        if value.to_s.length.positive?
          pdf.draw_text value.to_s, at: [2, box_h - 11], size: 8.5
        end
        pdf.line_width 0.6
        pdf.stroke_line [0, box_h - 14], [half, box_h - 14]
        pdf.draw_text caption, at: [2, box_h - 22], size: 6.5
      end
    end
    pdf.move_cursor_to(y_top - box_h - 4)
  end

  # ===================================================================== util

  def boxed_text(pdf, text, height:, width: nil)
    width ||= pdf.bounds.width
    top = pdf.cursor
    pdf.stroke do
      pdf.line_width 0.5
      pdf.rectangle [0, top], width, height
    end
    if text.to_s.strip.length.positive?
      # Use draw_text for single-line short fields (no auto-pagination); for taller
      # boxes use bounding_box with overflow:truncate, but ensure the inner height
      # is at least one full line of 8pt text so Prawn doesn't paginate.
      if height <= 14
        pdf.draw_text text.to_s, at: [5, top - height + 4], size: 7.5
      else
        pdf.bounding_box([5, top - 2], width: width - 10, height: height - 4) do
          pdf.text text.to_s, size: 7.5, overflow: :truncate, leading: 1
        end
      end
    end
    pdf.move_cursor_to(top - height - 2)
  end

  def answer_text(application, external_id)
    return nil unless application
    application.embassy_application_answers
               .joins(:question)
               .where(questions: { external_id: external_id })
               .first&.value_text
  end

  # ============================================================== pagination

  def paginate(pdf)
    serial = @application&.serial || "[BLANK]"
    total  = pdf.page_count
    pdf.repeat(:all, dynamic: true) do
      pdf.canvas do
        x = MARGIN
        y = 28
        w = pdf.bounds.width - 2 * MARGIN
        pdf.line_width 0.4
        pdf.stroke_color "999999"
        pdf.stroke_line [x, y + 14], [x + w, y + 14]
        pdf.fill_color  "666666"
        pdf.draw_text "Form RE-1 · Serial #{serial} · Page #{pdf.page_number} of #{total}",
                      at: [x + (w / 2.0) - 90, y], size: 7
        pdf.fill_color  "000000"
        pdf.stroke_color "000000"
      end
    end
  end
end
