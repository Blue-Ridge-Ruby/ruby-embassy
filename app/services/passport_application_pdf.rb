require "prawn"

# Builds the official Ruby Embassy passport application PDF.
#
# Aesthetic: as formal as a US tax form. No logo, no flourishes.
# DejaVu Sans throughout (TTF, broad Unicode coverage so user-typed glyphs
# outside Windows-1252 don't crash the renderer). Fine 0.5pt rules,
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

  FONT_DIR            = Rails.root.join("vendor", "fonts", "dejavu").freeze
  FONT_NAME           = "DejaVuSans".freeze
  FONT_NAME_CONDENSED = "DejaVuSansCondensed".freeze

  def initialize(application: nil, count: 1)
    @application = application
    @count       = count
  end

  def render
    pdf = Prawn::Document.new(page_size: PAGE_SIZE, margin: MARGIN)
    pdf.font_families.update(
      FONT_NAME => {
        normal:      FONT_DIR.join("DejaVuSans.ttf").to_s,
        bold:        FONT_DIR.join("DejaVuSans-Bold.ttf").to_s,
        italic:      FONT_DIR.join("DejaVuSans-Oblique.ttf").to_s,
        bold_italic: FONT_DIR.join("DejaVuSans-BoldOblique.ttf").to_s
      },
      FONT_NAME_CONDENSED => {
        normal:      FONT_DIR.join("DejaVuSansCondensed.ttf").to_s,
        bold:        FONT_DIR.join("DejaVuSansCondensed-Bold.ttf").to_s,
        italic:      FONT_DIR.join("DejaVuSansCondensed-Oblique.ttf").to_s,
        bold_italic: FONT_DIR.join("DejaVuSansCondensed-BoldOblique.ttf").to_s
      }
    )
    pdf.font FONT_NAME
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
    pdf.start_new_page
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
      [ "Notary's printed name", nil ],
      [ "Date executed",         nil ]
    ])
    pdf.move_down 12
    two_column_signatures(pdf, [
      [ "Notary's signature", nil ],
      [ "Notary ID (assigned)", notary&.external_id ]
    ])

    pdf.move_down 24
    pdf.text "FOR OFFICIAL EMBASSY USE ONLY", size: 8, style: :bold, align: :center
    pdf.stroke do
      pdf.line_width 0.5
      pdf.rectangle [ pdf.bounds.left, pdf.cursor - 4 ], pdf.bounds.width, 56
    end
    pdf.move_down 60
  end

  # ================================================================ sections

  # Rough lower bound to keep a section title from being orphaned at the bottom
  # of a page with no questions following it.
  MIN_SECTION_REMAINDER = 80

  def render_section(pdf, application, section_number, title, drawn: false)
    pdf.start_new_page if pdf.cursor < MIN_SECTION_REMAINDER

    pdf.move_down 8
    pdf.text "SECTION #{section_number}  ·  #{title}", size: 8.5, style: :bold
    pdf.stroke_horizontal_rule
    pdf.move_down 3

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

    pdf.bounding_box([ 0, y ], width: half, height: PAIRED_ROW_HEIGHT) do
      render_question_in_box(pdf, application, q1, label1, width: half, height: PAIRED_ROW_HEIGHT)
    end
    pdf.bounding_box([ half + gutter, y ], width: half, height: PAIRED_ROW_HEIGHT) do
      render_question_in_box(pdf, application, q2, label2, width: half, height: PAIRED_ROW_HEIGHT)
    end
    pdf.move_cursor_to(y - PAIRED_ROW_HEIGHT - 2)
  end

  # Fixed-position rendering for a half-width question inside a pair row.
  # Uses text_box (constrains width, truncates) so long labels don't overflow.
  def render_question_in_box(pdf, application, question, item_label, width:, height:)
    answer = application&.answer_for(question)
    label_text = "#{item_label}  #{question.label}"

    pdf.text_box label_text, at: [ 0, height - 1 ], width: width, height: 9,
                 size: 7.5, style: :bold, overflow: :truncate

    box_top = height - 11
    box_h   = 13
    pdf.line_width 0.5
    pdf.stroke_rectangle [ 0, box_top ], width, box_h

    value = answer&.display_value.to_s
    if value.length.positive?
      pdf.text_box value, at: [ 4, box_top - 2 ], width: width - 8, height: box_h - 4,
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
        { text: checked ? "[X] " : "[ ] ", styles: [ :bold ] },
        { text: "I affirm.", size: 7.5 }
      ]
    when "checkbox_group"
      render_checkbox_group(pdf, question, answer, width: width)
    end

    consumed = start_y - pdf.cursor
    pdf.move_down 2 if advance
    consumed + 2
  end

  # Checkbox group rendering — always uses a fixed-column grid so options
  # line up vertically within a question. Number of columns adapts to
  # option width: short options ("Vibes") get 4 cols on one line; medium
  # phrases get 3; longer affirmations like Section 4's drop to 2 columns.
  def render_checkbox_group(pdf, question, answer, width:)
    selected = Array(answer&.display_value)
    options  = question.options
    return if options.empty?

    cols = optimal_column_count(options, width)
    render_checkbox_group_grid(pdf, options, selected, width: width, cols: cols)
  end

  # Picks 1-4 columns based on the widest option's character length so each
  # column has room for the longest label without wrapping.
  def optimal_column_count(options, width)
    max_len = options.map(&:length).max
    char_w  = 3.8 # rough avg width of 7.5pt Helvetica char
    prefix  = 4   # "[X] "
    padding = 14
    col_width_needed = (max_len + prefix) * char_w + padding
    fit = (width / col_width_needed).floor
    fit.clamp(1, 4)
  end

  def render_checkbox_group_grid(pdf, options, selected, width:, cols:)
    col_width = (width - (cols - 1) * 8) / cols.to_f
    rows = (options.length.to_f / cols).ceil
    y = pdf.cursor
    options.each_with_index do |opt, i|
      row = i / cols
      col = i % cols
      x = col * (col_width + 8)
      pdf.bounding_box([ x, y - row * 10 ], width: col_width, height: 10) do
        pdf.formatted_text [
          { text: selected.include?(opt) ? "[X] " : "[ ] ", styles: [ :bold ] },
          { text: opt, size: 7.5 }
        ]
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
      [ "Serial No.",  serial ],
      [ "Appointment", when_text ],
      [ "Applicant",   applicant ],
      [ "Submitted",   submitted ]
    ])
    pdf.move_down 2
    pdf.stroke_horizontal_rule
  end

  def metadata_row(pdf, pairs)
    col_width = (pdf.bounds.width / pairs.length.to_f).floor
    y = pdf.cursor
    pdf.bounding_box([ 0, y ], width: pdf.bounds.width, height: 18) do
      pairs.each_with_index do |(label, value), i|
        pdf.bounding_box([ i * col_width, pdf.bounds.top ], width: col_width, height: 18) do
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
        "2. Answer all questions as printed. Substitution, omission, or creative reinterpretation may result in delay at the Embassy desk.",
        "3. The Notary in Part B of the Addendum must be located on Embassy premises and must affix their signature in the presence of the Embassy Attaché. Remote attestation is not recognized.",
        "4. Applicants are encouraged to arrive five (5) minutes before their appointment. Late arrivals may be accommodated at the Attaché's sole discretion.",
        "5. Use a pen. The Embassy does not provide pens, but reserves the right to comment on the Applicant's chosen instrument."
      ]
    ],
    [
      "EMBASSY ORDINANCES (EXCERPTED)",
      [
        "§1.  Validity. This application shall remain valid for the duration of Blue Ridge Ruby 2026 and may not be transferred to any subsequent calendar year, conference, or commemorative gathering. Validity does not survive the expiration of the lead maintainer's patience.",
        "§2.  Discretion. The Embassy reserves sole and absolute discretion to deny issuance for cause, including but not limited to: insufficient ceremony, ill-fitting suspenders, or a documented hatred of the Ruby programming language.",
        "§3.  Truthfulness. Falsified declarations may result in revocation of Ruby Embassy privileges for up to three (3) event days and forfeiture of any commemorative stamps so obtained. Repeat offenders may be required to write a sincere apology in YAML.",
        "§4.  Notary Conduct. The Applicant shall conduct themselves with reasonable courtesy toward the Notary. Bribery of the Notary is strictly prohibited unless said bribery consists of coffee, in which case discretion is advised.",
        "§5.  Right of Appeal. Applicants whose stamping is denied may request review by writing to noreply@blueridgeruby.com. Review proceedings, where granted, are conducted ex parte and concluded summarily.",
        "§6.  Liability. The Embassy assumes no liability for stamping-related psychological distress, including but not limited to: imposter syndrome, premature optimization, or the realization that one has been pronouncing \"RubyGems\" wrong this entire time.",
        "§7.  Decorum. The Applicant shall maintain decorum throughout proceedings, defined for purposes of this ordinance as: not laughing audibly during the stamping, not narrating the Notary's signature in real time, and not attempting to high-five the Attaché unless reciprocity is clearly indicated.",
        "§8.  Documentation. The Applicant must retain a copy of the stamped Passport for a period of not less than seven (7) calendar days, after which the document may be displayed on the Applicant's mantel, refrigerator, or other location of comparable ceremony.",
        "§9.  Reciprocal Recognition. The Embassy shall, upon request and at the Attaché's discretion, recognize Passports issued by sister Ruby Embassies hosted at other regional and international Ruby gatherings, subject to verification of the issuing event's standing.",
        "§10. Jurisdiction. Disputes arising under these ordinances shall be adjudicated within the geographic boundaries of Asheville, North Carolina, or wherever good coffee can be reasonably procured, whichever is more convenient.",
        "§11. Force Majeure. The Embassy shall not be held liable for failures caused by acts of God, acts of CDN, deprecated dependencies, expired SSL certificates, or the abrupt unavailability of the lead maintainer.",
        "§12. Amendments. These ordinances may be amended at any time by the Embassy Attaché, with or without notice, retroactively if necessary, and the Applicant hereby acknowledges this fact in advance and without further objection.",
        "§13. Counterparts. This document may be executed in counterparts, each of which shall be deemed an original, even when neither is, in fact, an original.",
        "§14. No Third-Party Beneficiaries. Nothing in this document creates rights enforceable by any third party, including but not limited to: the Applicant's coworkers, the Applicant's manager, the Applicant's mother, or the larger Ruby community at any historical moment.",
        "§15. Indemnification. The Applicant shall indemnify and hold harmless the Embassy, its Attachés, its Notaries, and any other persons who happened to be standing nearby, from any and all claims arising from the Applicant's voluntary participation in stamping ceremonies, including but not limited to claims sounding in tort, contract, or vibes.",
        "§16. Survival. The provisions of §6 (Liability), §14 (No Third-Party Beneficiaries), and §15 (Indemnification) shall survive the expiration, revocation, or stamping of any Passport issued hereunder, and shall continue in perpetuity or until the heat death of the framework, whichever occurs first.",
        "§17. Severability. Should any provision herein be deemed invalid by competent jurisdiction, the remaining provisions shall continue in full effect, possibly more so. Invalidated provisions may be reasonably construed to give effect to the parties' original ceremonial intent.",
        "§18. Entire Agreement. This document, together with the Notary Certification Addendum and any seal affixed thereto, constitutes the entire agreement between the Applicant and the Embassy and supersedes all prior promises, including those made over coffee, on Slack, or in conference hallways.",
        "§19. Conflict of Laws. In the event of any conflict between these ordinances and applicable Embassy precedent, these ordinances shall control. In the event of conflict between two clauses of these ordinances, the clause more inconvenient to the Applicant shall control.",
        "§20. Notices. All notices required hereunder shall be deemed given when transmitted by carrier pigeon, ceremonial scroll, or @-mention in the conference Slack, whichever the Embassy Attaché finds most amusing at the time."
      ]
    ],
    [
      "SCHEDULE A — DEFINITIONS",
      [
        "\"Applicant\" means the natural person identified in Section 1 of this Application, including any pseudonyms, callsigns, GitHub handles, or other documented aliases.",
        "\"Attaché\" means the duly appointed representative of the Embassy on premises during the three (3) event days, identifiable by official Embassy lanyard and a faintly weary expression.",
        "\"Business Gems\" means three (3) RubyGems published open source by Embassy personnel and listed on rubygems.org, irrespective of download count, semantic versioning practices, or whether such Gems remain actively maintained.",
        "\"Embassy\" means the Blue Ridge Ruby Embassy at Blue Ridge Ruby 2026, including all temporary structures, designated tables, hallway corners, and adjacent vibe zones.",
        "\"Notary\" means any attendee meeting the criteria set forth in Box A.1 of the Addendum, voluntarily acting in such capacity for purposes of this Application only.",
        "\"Passport\" means the formal document issued by the Embassy bearing one or more stamps of recognition, accompanied by such ceremony as the Attaché deems appropriate.",
        "\"Stamping\" means the act of applying said stamp to said Passport, performed by the Attaché in the presence of the Applicant and any onlookers who happen to be present.",
        "\"Vibe\" means the prevailing affective state at the Embassy at any given moment, which the Attaché shall have sole discretion to characterize, calibrate, or dismiss."
      ]
    ],
    [
      "SCHEDULE B — PROHIBITED ACTIVITIES",
      [
        "(a) Forgery, alteration, or material misrepresentation of any portion of this Application.",
        "(b) Acceptance of bribes from the Applicant, in any form other than the consensual transfer of caffeinated beverages.",
        "(c) Loud or sustained criticism of the Ruby programming language within audible range of the Embassy, except as part of an appeal duly filed under §5.",
        "(d) Solicitation of the Attaché's opinion on tabs vs. spaces, unless the Applicant is prepared to listen for an indeterminate period.",
        "(e) Conducting unauthorized parallel stamping ceremonies on Embassy premises or in any reasonable proximity thereto.",
        "(f) Use of the Embassy seal in any context not expressly authorized by the Embassy, including but not limited to social media avatars, conference badges, and unauthorized merchandise."
      ]
    ],
    [
      "SCHEDULE C — RULES OF CONSTRUCTION",
      [
        "1. Headings used herein are for convenience only and shall not affect interpretation, except where convenient interpretation favors the Embassy.",
        "2. References to the singular include the plural and vice versa, except where context clearly indicates the Applicant is a unique individual, in which case discretion is advised.",
        "3. \"Including\" shall mean \"including without limitation\" unless context requires otherwise, and even then, probably still without limitation.",
        "4. References to a person include such person's heirs, successors, executors, assigns, and the on-call engineer.",
        "5. Where this document refers to \"the Embassy,\" such reference shall include any tent, pop-up structure, table, designated chair, or unattended laptop temporarily designated as such by reasonable people.",
        "6. The phrase \"in the Embassy's sole discretion\" appears throughout this document and means precisely what it says, regardless of how aggrieved the Applicant may feel about it.",
        "7. Time periods specified in event days shall be calculated exclusive of weekends, recognized Embassy holidays, and any period during which the Attaché is on a coffee run."
      ]
    ],
    [
      "SCHEDULE D — REPRESENTATIONS AND WARRANTIES",
      [
        "The Applicant represents and warrants that, as of the date of this Application:",
        "(a) The Applicant has full legal capacity to enter into this ceremonial relationship with the Embassy;",
        "(b) The Applicant has read, or at least scrolled past, the entirety of the foregoing ordinances;",
        "(c) No other Embassy of any kind, whether real, parodic, or aspirational, has issued the Applicant a Passport that would create a conflict of allegiance herewith;",
        "(d) The Applicant is not knowingly under the influence of any framework or paradigm that would impair their judgment during the stamping ceremony;",
        "(e) All declarations made in Sections 1 through 5 above are true to the best of the Applicant's recollection, with allowances for the late hour; and",
        "(f) The Applicant understands that no warranty, express or implied, is made by the Embassy as to the durability, transferability, or impressiveness of any stamp issued hereunder."
      ]
    ],
    [
      "ACKNOWLEDGMENT",
      [
        "By submitting this Application, the Applicant acknowledges having read, understood, and willfully ignored the entirety of the foregoing ordinances. The Applicant further acknowledges that any disputes arising hereunder shall be resolved through informal mediation, which may include but is not limited to: a stern look from the Attaché, a brief lecture on community standards, or, in extreme cases, the writing of a strongly worded post-mortem.",
        "The Applicant additionally acknowledges that the Embassy retains the right to update, revise, supplement, deprecate, or rebrand any of the foregoing at any time, in any way, for any reason, with or without changelog.",
        "Should the Applicant wish to revoke this Acknowledgment, they may do so by completing a separate Form RE-7 (Notice of Withdrawal), which the Embassy has not yet drafted but reserves the right to draft retroactively.",
        "IN WITNESS WHEREOF, the Applicant has caused this Application to be executed by clicking a button on a website, which the Embassy hereby accepts as legally equivalent to a handwritten signature in indelible ink, notwithstanding any local jurisdiction's opinion on the matter."
      ]
    ]
  ].freeze

  FOOTER_RESERVE = 20 # space the page footer occupies at the bottom

  def render_instructions(pdf)
    pdf.move_down 12
    box_top    = pdf.cursor
    box_height = box_top - FOOTER_RESERVE

    # Condensed face for the legal text only — narrower glyphs let the full
    # body of ordinances and schedules pack into one page's 3-column block.
    pdf.font(FONT_NAME_CONDENSED) do
      pdf.column_box([ 0, box_top ], columns: 3, width: pdf.bounds.width,
                     height: box_height, spacer: 10) do
        INSTRUCTIONS.each_with_index do |(title, paragraphs), i|
          pdf.move_down 5 if i > 0

          pdf.text title, size: 6.5, style: :bold
          pdf.stroke_horizontal_rule
          pdf.move_down 3
          paragraphs.each do |para|
            pdf.text para, size: 5.5, leading: 0.5, color: "333333", align: :justify
            pdf.move_down 1
          end
        end
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

    submitted_on = application&.submitted_at&.strftime("%Y-%m-%d") || ""

    two_column_signatures(pdf, [
      [ "Signature of Applicant", nil ],
      [ "Date executed",          submitted_on ]
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
      pdf.bounding_box([ x, y_top ], width: half, height: box_h) do
        if value.to_s.length.positive?
          pdf.draw_text value.to_s, at: [ 2, box_h - 11 ], size: 8.5
        end
        pdf.line_width 0.6
        pdf.stroke_line [ 0, box_h - 14 ], [ half, box_h - 14 ]
        pdf.draw_text caption, at: [ 2, box_h - 22 ], size: 6.5
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
      pdf.rectangle [ 0, top ], width, height
    end
    if text.to_s.strip.length.positive?
      # Use draw_text for single-line short fields (no auto-pagination); for taller
      # boxes use bounding_box with overflow:truncate, but ensure the inner height
      # is at least one full line of 8pt text so Prawn doesn't paginate.
      if height <= 14
        pdf.draw_text text.to_s, at: [ 5, top - height + 4 ], size: 7.5
      else
        pdf.bounding_box([ 5, top - 2 ], width: width - 10, height: height - 4) do
          pdf.text text.to_s, size: 7.5, overflow: :truncate, leading: 1
        end
      end
    end
    pdf.move_cursor_to(top - height - 2)
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
        pdf.stroke_line [ x, y + 14 ], [ x + w, y + 14 ]
        pdf.fill_color  "666666"
        pdf.draw_text "Form RE-1 · Serial #{serial} · Page #{pdf.page_number} of #{total}",
                      at: [ x + (w / 2.0) - 90, y ], size: 7
        pdf.fill_color "000000"
        pdf.stroke_color "000000"
      end
    end
  end
end
