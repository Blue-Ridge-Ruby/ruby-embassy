module FakeEmbassy
  module_function

  MODES = %w[new_passport stamping both].freeze

  def mode_for(schedule_item_id)
    MODES[schedule_item_id.to_i % MODES.length]
  end

  def mode_label(mode)
    {
      "new_passport" => "New passport",
      "stamping"     => "Stamping",
      "both"         => "New passport or Stamping"
    }[mode] || "—"
  end

  def mode_short(mode)
    { "new_passport" => "New passport", "stamping" => "Stamping", "both" => "New or Stamp" }[mode]
  end

  def capacity_for(schedule_item_id)
    [ 6, 8, 10, 12 ][schedule_item_id.to_i % 4]
  end

  def seats_taken_for(schedule_item_id)
    [ 2, 3, 5, 7 ][schedule_item_id.to_i % 4].clamp(0, capacity_for(schedule_item_id))
  end

  def seats_remaining(schedule_item_id)
    capacity_for(schedule_item_id) - seats_taken_for(schedule_item_id)
  end

  def full?(schedule_item_id)
    seats_remaining(schedule_item_id) <= 0
  end

  STATES = %w[stamping pending submitted expired].freeze

  def appointment_state_for(plan_item_id)
    STATES[plan_item_id.to_i % STATES.length]
  end

  def serial_for(id)
    letter = ("A".."Z").to_a[id.to_i % 26]
    "RE-0427-#{letter}"
  end

  def reservation_minutes_left(plan_item_id)
    [ 47, 32, 18, 3 ][plan_item_id.to_i % 4]
  end

  # === Section 1 · Declaration of Ruby-ness (COMMON) ========================
  # Identity, background, and the signature relationship question. Every
  # applicant answers these. The Matz question lives here deliberately so
  # every Ruby Embassy passport is stamped with a personal answer.
  SECTION_1_QUESTIONS = [
    { id: "1a", label: "Given Name (as it appears on your Tito badge)",
      type: :short, required: true, placeholder: "e.g., Katya" },
    { id: "1b", label: "GitHub handle",
      type: :short, required: false, help: "Your @handle on GitHub." },
    { id: "1c", label: "Preferred pronouns",
      type: :short, required: false },
    { id: "1d", label: "First Ruby release you remember using",
      type: :select, required: true,
      options: [ "1.8.x", "1.9.x", "2.0–2.6", "2.7–3.0", "3.1+", "I refuse to answer" ] },
    { id: "1e", label: "Ruby release you most miss",
      type: :short, required: false, placeholder: "e.g., 1.8.7, for sentimental reasons" },
    { id: "1f", label: "Describe, in one paragraph, your relationship to Yukihiro Matsumoto",
      type: :long, required: true, help: "Literal or metaphorical answers both accepted." }
  ].freeze

  # === Section 2 · Supplementary Declarations (RANDOM POOL, draws 4 of 8) ===
  # Internally a random pool that draws a different subset per application.
  # Users must not know this: the section title, instructions, and rendering
  # should all look like any other section of a standard embassy form.
  # Admins manage the pool via the Question Bank.
  SECTION_2_POOL = [
    { id: "2a", label: "How many keyboards do you currently own?",
      type: :select, required: false,
      options: [ "0", "1", "2–3", "4–6", "More than I am willing to admit" ] },
    { id: "2b", label: "Preferred test runner",
      type: :select, required: false,
      options: [ "RSpec", "Minitest", "Both, depending on mood", "Neither, I test in production" ] },
    { id: "2c", label: "Most embarrassing production incident (brief)",
      type: :long, required: false, help: "Names will be redacted. Scars will not." },
    { id: "2d", label: "Worst Rails upgrade story, in three sentences",
      type: :long, required: false },
    { id: "2e", label: "If Ruby were a beverage, what beverage would it be?",
      type: :short, required: false, placeholder: "e.g., a warm amaro, a slow espresso" },
    { id: "2f", label: "Have you ever written method_missing? If so, how did it feel?",
      type: :long, required: false,
      help: "Responses involving \"transcendent\" or \"regret\" will be evaluated equally." },
    { id: "2g", label: "Name one gem that does not spark joy",
      type: :short, required: false },
    { id: "2h", label: "Pair programming: describe your emotional relationship to the practice",
      type: :long, required: false }
  ].freeze

  # Deterministic draw for the stable mockup preview.
  SECTION_2_DRAWN_IDS = %w[2a 2b 2e 2f].freeze
  SECTION_2_DRAWS = 4

  # === Section 3 · Affidavit of Attendance (COMMON) =========================
  SECTION_3_QUESTIONS = [
    { id: "3a", label: "I affirm I will respect the Embassy's Ruby-only policy for the duration of my visit",
      type: :checkbox, required: true },
    { id: "3b", label: "Date of arrival in Asheville",
      type: :date, required: true },
    { id: "3c", label: "Are you currently in possession of unreleased gems of unknown provenance?",
      type: :select, required: true,
      options: [ "No", "Yes", "I plead the fifth" ] },
    { id: "3d", label: "Signature (type your full legal name)",
      type: :short, required: true,
      help: "This carries the same legal weight as a stamped declaration, which is to say: very little." }
  ].freeze

  def sample_questions
    [
      { number: 1,
        title: "Declaration of Ruby-ness",
        instructions: "Print clearly. This section establishes your eligibility under Embassy Ordinance §1.9.",
        scope: "common",
        questions: SECTION_1_QUESTIONS },

      # NOTE: title + instructions here are deliberately neutral — users
      # must not know this section is randomized. Admin surfaces (question
      # bank, applications detail) expose the scope/draws metadata.
      { number: 2,
        title: "Supplementary Declarations",
        instructions: "Please respond to the following to the best of your ability. Answers are retained for statistical and adjudication purposes.",
        scope: "random_pool",
        draws: SECTION_2_DRAWS,
        pool_size: SECTION_2_POOL.length,
        questions: SECTION_2_POOL.select { |q| SECTION_2_DRAWN_IDS.include?(q[:id]) } },

      { number: 3,
        title: "Affidavit of Attendance",
        instructions: "Falsified answers may result in revocation of Ruby Embassy privileges for up to three business gems.",
        scope: "common",
        questions: SECTION_3_QUESTIONS }
    ]
  end

  FILLED_ANSWERS = {
    # Section 1 — common
    "1a" => "Katya",
    "1b" => "@kitkatnik",
    "1c" => "she/her",
    "1d" => "2.7–3.0",
    "1e" => "1.8.7 — the heart wants what it wants",
    "1f" => "We've never spoken, but I feel his presence every time I write a block. Once, while writing a method_missing, I felt we achieved mutual understanding.",
    # Section 2 — random pool (values for all pool members; only drawn ones render)
    "2a" => "2–3",
    "2b" => "Minitest",
    "2c" => "Rolled a migration, rolled the wrong direction, rolled my chair into a wall.",
    "2d" => "We upgraded 4.2 to 5.0. We upgraded 5.0 to 5.1. We stopped upgrading.",
    "2e" => "A warm amaro, drunk slowly on a porch.",
    "2f" => "Yes. Transcendent, then regretful, then transcendent again.",
    "2g" => "The one that shall not be named.",
    "2h" => "Pair programming is the one time my keyboard is not mine.",
    # Section 3 — common
    "3a" => true,
    "3b" => "2026-04-29",
    "3c" => "I plead the fifth",
    "3d" => "Katya Sarmiento"
  }.freeze

  def filled_answer(question_id)
    FILLED_ANSWERS[question_id]
  end

  def submitted_applications
    [
      { serial: "RE-0427-A", attendee_name: "Katya Sarmiento", attendee_email: "software@adhdcoder.com",
        slot: "Sat May 2 · 2:00 PM", submitted_at: "Apr 30 · 3:14 PM",
        drawn_ids: %w[2a 2b 2e 2f] },
      { serial: "RE-0427-B", attendee_name: "John Athayde",    attendee_email: "john@example.com",
        slot: "Sat May 2 · 2:00 PM", submitted_at: "Apr 30 · 4:02 PM",
        drawn_ids: %w[2c 2d 2f 2h] },
      { serial: "RE-0427-C", attendee_name: "Aaron Patterson", attendee_email: "aaron@example.com",
        slot: "Sat May 2 · 2:15 PM", submitted_at: "May 1 · 9:11 AM",
        drawn_ids: %w[2a 2d 2e 2g] },
      { serial: "RE-0427-D", attendee_name: "Sandi Metz",      attendee_email: "sandi@example.com",
        slot: "Sat May 2 · 2:15 PM", submitted_at: "May 1 · 10:48 AM",
        drawn_ids: %w[2b 2c 2f 2h] },
      { serial: "RE-0427-E", attendee_name: "Avdi Grimm",      attendee_email: "avdi@example.com",
        slot: "Sat May 2 · 2:30 PM", submitted_at: "May 1 · 11:02 AM",
        drawn_ids: %w[2a 2c 2d 2g] },
      { serial: "RE-0427-F", attendee_name: "Mislav Marohnić", attendee_email: "mislav@example.com",
        slot: "Sat May 2 · 2:30 PM", submitted_at: "May 1 · 12:19 PM",
        drawn_ids: %w[2a 2e 2f 2h] },
      { serial: "RE-0427-G", attendee_name: "Penelope Phippen", attendee_email: "penelope@example.com",
        slot: "Sat May 2 · 2:45 PM", submitted_at: "May 1 · 1:45 PM",
        drawn_ids: %w[2b 2c 2d 2g] }
    ]
  end

  def find_submitted_application(serial)
    submitted_applications.find { |a| a[:serial] == serial } ||
      { serial: serial, attendee_name: "Unknown", attendee_email: "—",
        slot: "—", submitted_at: "—", drawn_ids: SECTION_2_DRAWN_IDS.dup }
  end

  # Sections + their questions rendered for a SPECIFIC submitted application.
  # Admin detail view uses this to show the exact random draw that attendee
  # received, instead of the default mockup draw.
  def sections_for(application)
    drawn = application[:drawn_ids] || SECTION_2_DRAWN_IDS
    sample_questions.map do |section|
      next section unless section[:scope] == "random_pool"
      section.merge(questions: SECTION_2_POOL.select { |q| drawn.include?(q[:id]) })
    end
  end

  # Flat bank for the admin Question Bank index. Includes ALL random-pool
  # members (not just drawn) so admins can manage the full set.
  def question_bank
    bank = []
    SECTION_1_QUESTIONS.each do |q|
      bank << q.merge(
        section: 1, section_title: "Declaration of Ruby-ness",
        section_scope: "common", status: "active",
        usage_count: deterministic_usage(q[:id])
      )
    end
    SECTION_2_POOL.each do |q|
      bank << q.merge(
        section: 2, section_title: "Supplementary Declarations",
        section_scope: "random_pool", status: "active",
        usage_count: deterministic_usage(q[:id])
      )
    end
    SECTION_3_QUESTIONS.each do |q|
      bank << q.merge(
        section: 3, section_title: "Affidavit of Attendance",
        section_scope: "common", status: "active",
        usage_count: deterministic_usage(q[:id])
      )
    end
    bank << {
      id: "X1", section: 0, section_title: "Archived",
      section_scope: "common",
      label: "Preferred blend of Ruby Roast coffee (retired question)",
      type: :select, required: false, usage_count: 12, status: "archived"
    }
    bank
  end

  # Metadata per section — used on admin surfaces to expose the scope.
  SECTION_META = {
    1 => { title: "Declaration of Ruby-ness",   scope: "common",
           hint: "Every applicant fills these out." },
    2 => { title: "Supplementary Declarations", scope: "random_pool",
           hint: "Internally a random pool — draws 4 of 8 per application. Users see only a numbered section.",
           draws: 4 },
    3 => { title: "Affidavit of Attendance",    scope: "common",
           hint: "Every applicant fills these out." }
  }.freeze

  def section_meta
    SECTION_META
  end

  def find_question(question_id)
    question_bank.find { |q| q[:id] == question_id } || question_bank.first
  end

  def embassy_etiquette
    [
      "Please arrive 5 minutes before your appointment time.",
      "Bring your printed application. Unprinted applications will be filled out on-site — paper only, please.",
      "Stamping appointments require an existing Ruby passport. No passport, no stamp.",
      "Photography inside the Embassy Office is permitted, but do not photograph the Stamping Apparatus.",
      "The Embassy Office is located in the Main Hall. Look for the ruby-red awning."
    ]
  end

  def embassy_hours
    [
      "Saturday, May 2 · 1:00 PM – 5:00 PM",
      "Sunday, May 3 · 9:00 AM – 12:00 PM (stamping only)"
    ]
  end

  def deterministic_usage(id)
    40 + (id.to_s.bytes.sum % 25)
  end
end
