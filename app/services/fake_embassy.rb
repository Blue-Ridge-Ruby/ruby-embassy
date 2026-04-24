require Rails.root.join("db/seeds/embassy_questions").to_s

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

  # Deterministic draw shown on the default (Katya's) mockup preview.
  DEFAULT_DRAWN_POOL_IDS = %w[3a01 3b05 3c04 3e03 3h03].freeze
  DEFAULT_NOTARY_ID      = "N01".freeze

  def sample_questions(drawn_ids: DEFAULT_DRAWN_POOL_IDS)
    [
      {
        number: 1, title: "Declaration of Ruby-ness",
        scope: "common",
        instructions: "Print clearly. This section establishes the Applicant's eligibility for Passport issuance pursuant to Embassy Ordinance §1.9.",
        questions: EmbassyQuestionsSeed::BASIC_INFO
      },
      {
        number: 2, title: "Statement of Intent & Character",
        scope: "common",
        instructions: "The Applicant is required to disclose, in their own words, certain particulars of their programming disposition. Literal or metaphorical responses both accepted. Do not leave blank.",
        questions: EmbassyQuestionsSeed::PERSONAL_STATEMENT
      },
      {
        # NOTE: title + instructions here are deliberately neutral — users
        # must not know this section is randomized. Admin surfaces expose
        # the scope/draws metadata.
        number: 3, title: "Supplementary Declarations",
        scope: "random_pool",
        instructions: "The following declarations are required under Embassy Ordinance §3.14. Answers are filed in perpetuity and may be referenced at any future Embassy proceeding.",
        draws: EmbassyQuestionsSeed::RANDOM_POOL_DRAWS,
        pool_size: EmbassyQuestionsSeed::RANDOM_POOL.length,
        questions: EmbassyQuestionsSeed::RANDOM_POOL.select { |q| drawn_ids.include?(q[:id]) }
      },
      {
        number: 4, title: "Attestation of Community Standing",
        scope: "common",
        instructions: "Each of the following is deemed material to the Embassy's assessment of community fitness under Ordinance §4.1. The Applicant is asked to affirm or decline without reservation.",
        questions: EmbassyQuestionsSeed::COMMUNITY_ALIGNMENT
      },
      {
        number: 5, title: "Affidavit of Attendance",
        scope: "common",
        instructions: "Falsified statements may result in revocation of Ruby Embassy privileges for up to three (3) business gems. The Applicant signs below under penalty of Rubocop.",
        questions: EmbassyQuestionsSeed::DECLARATION
      }
    ]
  end

  # Returns sections customized for a specific submitted application so
  # the admin sees the exact draw that attendee received.
  def sections_for(application)
    drawn = application[:drawn_ids] || DEFAULT_DRAWN_POOL_IDS
    sample_questions(drawn_ids: drawn)
  end

  # Notary drawn for a given application (or the default for the preview).
  def notary_for(application = nil)
    target_id = (application && application[:notary_id]) || DEFAULT_NOTARY_ID
    EmbassyQuestionsSeed::NOTARY_POOL.find { |n| n[:id] == target_id } ||
      EmbassyQuestionsSeed::NOTARY_POOL.first
  end

  FILLED_ANSWERS = {
    # Section 1 · Basic Info ----------------------------------------------
    "1a" => "Katya",
    "1b" => "@kitkatnik",
    "1c" => "she/her",
    "1d" => "9 years of Ruby, 14 years of existential dread",
    "1e" => "$0. Audit me, I dare you.",
    "1f" => "I use Ruby",
    "1g" => "Go",
    "1h" => [ "Networking", "Vibes", "Free coffee" ],
    "1i" => [ "Powerful", "Confused", "Like quitting forever" ],
    "1j" => [ "The Debugger", "The \"it works don't touch it\"" ],

    # Section 2 · Personal Statement --------------------------------------
    "2a" => "Programming and I have been together long enough that we finish each other's error messages.",
    "2b" => "2.7–3.0",
    "2c" => "1.8.7 — the heart wants what it wants",
    "2d" => "We've never spoken, but I feel his presence every time I write a block. Once, while writing a method_missing, I felt we achieved mutual understanding.",

    # Section 3 · Supplementary Declarations (answers for every pool member,
    # so any drawn subset renders correctly on any submitted application view)
    "3a01" => "I once spent six hours debugging a production issue caused by a stray space in a CSV.",
    "3a02" => "A migration that silently dropped 12% of user records. It 'passed review.'",
    "3a03" => "The time I moved a file up two directories and 40 tests suddenly passed.",
    "3a04" => "A method_missing handler that recursed through ActiveRecord looking for 'something that resembles a category.'",
    "3a05" => "Regex. The answer is always regex.",
    "3a06" => "I forgot to save the file for two hours.",
    "3a07" => "Someone put a string comparison inside a callback that runs on every page load.",

    "3b01" => "If your test suite takes more than 90 seconds, it is a todo list, not a test suite.",
    "3b02" => "I never run `bin/rails console --sandbox`. I live dangerously.",
    "3b03" => "TDD. There, I said it.",
    "3b04" => "Monorepos. They're fine. Stop fighting about this.",
    "3b05" => "Misunderstood genius, but only for the first two years.",
    "3b06" => "Situationship. It keeps calling me at 2am with production issues.",
    "3b07" => "CoffeeScript. It is a haunted language and we all know it.",

    "3c01" => "It would tolerate me, the way a cat tolerates a roommate who pays the rent.",
    "3c02" => "Rookie of the year, 2013. Did not win a match but showed up to all of them.",
    "3c03" => "Passive-aggressive. Writes emails that are technically polite.",
    "3c04" => "`tap`. Sneaky and elegant.",
    "3c05" => "My past self would be horrified. We would not be speaking by the end of it.",
    "3c06" => "Because the incident report writes itself.",
    "3c07" => "I would simply start using Sinatra apps and eating dinner outside.",

    "3d01" => "A GeoCities page that would not load a rotating star GIF. I swore revenge.",
    "3d02" => "The brief moment after a bug is fixed and before the next one appears.",
    "3d03" => "A three-day Heisenbug that turned out to be a renamed column.",
    "3d04" => "Knitting. It teaches you to unpick mistakes without crying.",
    "3d05" => "Dark mode. Ambient music. A windowless room. No humans within 100 feet.",
    "3d06" => "Walk. Shower. Complain to the duck on my desk. Return.",

    "3e01" => "Cottagecore with a vengeance.",
    "3e02" => "Somewhere between 'I got this' and 'what is a kernel'.",
    "3e03" => "A Heisenbug. You think you've seen me, then doubt it.",
    "3e04" => "The distracted-boyfriend meme, but it's me looking at a new framework.",
    "3e05" => "1 of 10. The rest are Stack Overflow tabs.",
    "3e06" => "Three. Always three. I never learn.",

    "3f01" => "A community cookbook where every recipe comes with the grandmother's handwriting.",
    "3f02" => "A habit tracker. I was not sufficiently in the habit of maintaining it.",
    "3f03" => "A CLI that tells you whether your commit message is too funny for the branch.",
    "3f04" => "A Mastodon bot that posts fake Ruby Weekly editions.",
    "3f05" => "An entire second career in basket weaving.",

    "3g01" => "Yes. The project was 37% done. I said 'this weekend.'",
    "3g02" => "10pm. Docker. Three caffeinated beverages. Sincere apology to my keyboard.",
    "3g03" => "Fixed a race condition. Broke every feature flag.",
    "3g04" => "I have nodded gravely through entire standups.",
    "3g05" => "`legacy/billing_tax_legacy.rb`. Last touched 2014. Still running.",
    "3g06" => "A cron job that periodically restarts a daemon. Nobody has ever fixed it.",

    "3h01" => "To remember why I liked Ruby in the first place.",
    "3h02" => "To meet one person whose blog I've been reading since 2017.",
    "3h03" => "Stand near the coffee. Wear sunglasses until 9am. Assume every hallway is a shortcut.",
    "3h04" => "Four.",
    "3h05" => "Avoid responsibilities, but enthusiastically.",

    "3i01" => "Pray. Monitor. Consider turning off the internet.",
    "3i02" => "Check env vars. Check secrets. Blame the cache. Find the typo.",
    "3i03" => "Find the oldest test file. Read it aloud. Decide if I can live here.",
    "3i04" => "'Works on my machine' is the first half of a really useful sentence.",
    "3i05" => "Open the editor. Stare. Close the editor. Rest.",

    "3j01" => "4–6.",
    "3j02" => "Minitest.",
    "3j03" => "Rolled a migration, rolled the wrong direction, rolled my chair into a wall.",
    "3j04" => "We upgraded 4.2 to 5.0. We upgraded 5.0 to 5.1. We stopped upgrading.",
    "3j05" => "A warm amaro, drunk slowly on a porch.",
    "3j06" => "Yes. Transcendent, then regretful, then transcendent again.",
    "3j07" => "The one that shall not be named.",
    "3j08" => "Pair programming is the one time my keyboard is not mine.",

    # Section 4 · Community Alignment -------------------------------------
    "4a" => [
      "I believe debugging builds character",
      "I have questioned my life choices while coding",
      "I have said \"this should work\" (it did not)",
      "I have fixed something and broken something else",
      "I have Googled the same error more than once"
    ],

    # Section 5 · Declaration ---------------------------------------------
    "5a" => true,
    "5b" => "2026-04-29",
    "5c" => "I plead the fifth",
    "5d" => "Katya Sarmiento"
  }.freeze

  def filled_answer(question_id)
    FILLED_ANSWERS[question_id]
  end

  def submitted_applications
    [
      { serial: "RE-0427-A", attendee_name: "Katya Sarmiento",  attendee_email: "software@adhdcoder.com",
        slot: "Sat May 2 · 2:00 PM", submitted_at: "Apr 30 · 3:14 PM",
        drawn_ids: %w[3a01 3b05 3c04 3e03 3h03], notary_id: "N01" },
      { serial: "RE-0427-B", attendee_name: "John Athayde",     attendee_email: "john@example.com",
        slot: "Sat May 2 · 2:00 PM", submitted_at: "Apr 30 · 4:02 PM",
        drawn_ids: %w[3a04 3b02 3c06 3d01 3g02], notary_id: "N05" },
      { serial: "RE-0427-C", attendee_name: "Aaron Patterson",  attendee_email: "aaron@example.com",
        slot: "Sat May 2 · 2:15 PM", submitted_at: "May 1 · 9:11 AM",
        drawn_ids: %w[3a02 3b07 3c07 3d03 3h01], notary_id: "N13" },
      { serial: "RE-0427-D", attendee_name: "Sandi Metz",       attendee_email: "sandi@example.com",
        slot: "Sat May 2 · 2:15 PM", submitted_at: "May 1 · 10:48 AM",
        drawn_ids: %w[3a05 3b06 3c01 3f01 3g04], notary_id: "N02" },
      { serial: "RE-0427-E", attendee_name: "Avdi Grimm",       attendee_email: "avdi@example.com",
        slot: "Sat May 2 · 2:30 PM", submitted_at: "May 1 · 11:02 AM",
        drawn_ids: %w[3a07 3b03 3c05 3d06 3i02], notary_id: "N09" },
      { serial: "RE-0427-F", attendee_name: "Mislav Marohnić",  attendee_email: "mislav@example.com",
        slot: "Sat May 2 · 2:30 PM", submitted_at: "May 1 · 12:19 PM",
        drawn_ids: %w[3a03 3b04 3c03 3e01 3i05], notary_id: "N15" },
      { serial: "RE-0427-G", attendee_name: "Penelope Phippen", attendee_email: "penelope@example.com",
        slot: "Sat May 2 · 2:45 PM", submitted_at: "May 1 · 1:45 PM",
        drawn_ids: %w[3a06 3b01 3c02 3f03 3h02], notary_id: "N08" }
    ]
  end

  def find_submitted_application(serial)
    submitted_applications.find { |a| a[:serial] == serial } ||
      { serial: serial, attendee_name: "Unknown", attendee_email: "—",
        slot: "—", submitted_at: "—",
        drawn_ids: DEFAULT_DRAWN_POOL_IDS.dup, notary_id: DEFAULT_NOTARY_ID }
  end

  # === Admin: flat question bank for the Question Bank index ==============
  def question_bank
    bank = []

    EmbassyQuestionsSeed::BASIC_INFO.each do |q|
      bank << q.merge(
        section: 1, section_title: "Declaration of Ruby-ness",
        section_scope: "common", status: "active",
        usage_count: deterministic_usage(q[:id])
      )
    end

    EmbassyQuestionsSeed::PERSONAL_STATEMENT.each do |q|
      bank << q.merge(
        section: 2, section_title: "Statement of Intent & Character",
        section_scope: "common", status: "active",
        usage_count: deterministic_usage(q[:id])
      )
    end

    EmbassyQuestionsSeed::RANDOM_POOL_CATEGORIES.each do |key, category|
      category[:questions].each do |q|
        bank << q.merge(
          section: 3, section_title: "Supplementary Declarations",
          section_scope: "random_pool",
          category: key, category_title: category[:title],
          status: "active",
          usage_count: deterministic_usage(q[:id])
        )
      end
    end

    EmbassyQuestionsSeed::COMMUNITY_ALIGNMENT.each do |q|
      bank << q.merge(
        section: 4, section_title: "Attestation of Community Standing",
        section_scope: "common", status: "active",
        usage_count: deterministic_usage(q[:id])
      )
    end

    EmbassyQuestionsSeed::DECLARATION.each do |q|
      bank << q.merge(
        section: 5, section_title: "Affidavit of Attendance",
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

  # Notary pool — shown in its own admin block below the question table.
  def notary_pool
    EmbassyQuestionsSeed::NOTARY_POOL.map do |n|
      n.merge(
        followup_count: n[:followups].length,
        usage_count: deterministic_usage(n[:id]),
        status: "active"
      )
    end
  end

  # Per-section metadata for admin question-bank index headers.
  SECTION_META = {
    1 => { title: "Declaration of Ruby-ness",          scope: "common",
           hint: "Identity, proficiency, declared disposition. Every applicant fills these out." },
    2 => { title: "Statement of Intent & Character",   scope: "common",
           hint: "Free-form personal statement. Every applicant fills these out." },
    3 => { title: "Supplementary Declarations",        scope: "random_pool",
           hint: "Internally a random pool — draws %{draws} of %{total} per application. Users see only a numbered section.",
           draws: EmbassyQuestionsSeed::RANDOM_POOL_DRAWS },
    4 => { title: "Attestation of Community Standing", scope: "common",
           hint: "Single checkbox group. Every applicant affirms the applicable statements." },
    5 => { title: "Affidavit of Attendance",           scope: "common",
           hint: "Signature, arrival date, final attestations. Every applicant fills these out." }
  }.freeze

  def section_meta
    SECTION_META
  end

  def random_pool_total
    EmbassyQuestionsSeed::RANDOM_POOL.length
  end

  def random_pool_draws
    EmbassyQuestionsSeed::RANDOM_POOL_DRAWS
  end

  def random_pool_categories
    EmbassyQuestionsSeed::RANDOM_POOL_CATEGORIES
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
