# Ruby Embassy — Application Question Seed Data
#
# Source of truth for the initial Question Bank and Notary Pool. Loaded
# via `EmbassyQuestionsSeed.import!` from `db/seeds.rb`.
#
# The constants below are private to the importer. After the first seed,
# admins manage Questions and NotaryProfiles through `/admin/embassy_questions`
# — this file is only re-read when wiping/reseeding development data.
#
# `external_id` (e.g. "1a", "3a01", "N02") is the natural key used for
# upsert. Existing records are updated in place; new ones are created.
# Application data (answers, applications themselves) is never touched.

module EmbassyQuestionsSeed
  module_function

  def import!
    Question.transaction do
      normalize(COMMON_SECTION_1).each_with_index { |attrs, i| upsert_question(attrs.merge(section: 1, position: i, scope: "common")) }
      normalize(COMMON_SECTION_2).each_with_index { |attrs, i| upsert_question(attrs.merge(section: 2, position: i, scope: "common")) }
      normalize(RANDOM_POOL).each_with_index      { |attrs, i| upsert_question(attrs.merge(section: 3, position: i, scope: "random_pool")) }
      normalize(COMMON_SECTION_4).each_with_index { |attrs, i| upsert_question(attrs.merge(section: 4, position: i, scope: "common")) }
      normalize(COMMON_SECTION_5).each_with_index { |attrs, i| upsert_question(attrs.merge(section: 5, position: i, scope: "common")) }
    end

    NotaryProfile.transaction do
      NOTARY_POOL.each { |attrs| upsert_notary(attrs) }
    end
  end

  def upsert_question(attrs)
    record = Question.find_or_initialize_by(external_id: attrs[:external_id])
    record.section     = attrs[:section]
    record.position    = attrs[:position]
    record.label       = attrs[:label]
    record.help        = attrs[:help]
    record.placeholder = attrs[:placeholder]
    record.field_type  = attrs[:field_type]
    record.required    = attrs.fetch(:required, false)
    record.scope       = attrs[:scope]
    record.status      = "active" if record.new_record?
    record.options     = attrs.fetch(:options, [])
    record.save!
  end

  def upsert_notary(attrs)
    record = NotaryProfile.find_or_initialize_by(external_id: attrs[:external_id])
    record.description     = attrs[:description]
    record.followup_prompt = attrs[:followup_prompt]
    record.status          = "active" if record.new_record?
    record.save!
  end

  def normalize(raw)
    raw.map do |q|
      {
        external_id: q[:id],
        label:       q[:label],
        help:        q[:help],
        placeholder: q[:placeholder],
        field_type:  q[:type].to_s,
        required:    q.fetch(:required, false),
        options:     q.fetch(:options, [])
      }
    end
  end

  # === Section 1 · Declaration of Ruby-ness ================================
  COMMON_SECTION_1 = [
    { id: "1a", label: "Given Name (as it appears on your Tito badge)",
      type: :short, required: true, placeholder: "e.g., Katya" },
    { id: "1b", label: "GitHub handle", type: :short, required: false,
      help: "The Applicant's @handle on GitHub, where applicable." },
    { id: "1c", label: "Preferred pronouns", type: :short, required: false },
    { id: "1d", label: "Age, in Coding Years", type: :short, required: false,
      placeholder: "e.g., 9 years of Ruby, 14 years of existential dread",
      help: "For adjudication purposes only. The Embassy does not acknowledge biological years." },
    { id: "1e", label: "Declared Ruby Proficiency", type: :select, required: true,
      options: ["Just installed it", "I use Ruby", "I fight Ruby", "I am Ruby"] },
    { id: "1f", label: "Primary language, other than Ruby", type: :short, required: false,
      placeholder: "e.g., Go, Elixir, Fortran, Emotional Support" },
    { id: "1g", label: "Stated purpose of visit (select all that apply)",
      type: :checkbox_group, required: false,
      options: ["Learning", "Networking", "Vibes", "Free coffee"] },
    { id: "1h", label: "Most recent sentiment experienced while programming (select all that apply)",
      type: :checkbox_group, required: false,
      options: ["Powerful", "Confused", "Betrayed", "Like a genius", "Like quitting forever"] },
    { id: "1i", label: "Declared developer persona (select all that apply)",
      type: :checkbox_group, required: false,
      options: ["The Debugger", "The Ship-It Gremlin", "The Perfectionist",
                "The \"it works, don't touch it\"", "The Vibe Coder"] }
  ].freeze

  # === Section 2 · Statement of Intent & Character =========================
  COMMON_SECTION_2 = [
    { id: "2a", label: "Describe the Applicant's current relationship with programming, in one sentence",
      type: :long, required: true },
    { id: "2b", label: "First Ruby release the Applicant remembers using",
      type: :select, required: false,
      options: ["1.8.x", "1.9.x", "2.0–2.6", "2.7–3.0", "3.1+", "I refuse to answer"] },
    { id: "2c", label: "Ruby release for which the Applicant harbors sentimental attachment",
      type: :short, required: false,
      placeholder: "e.g., 1.8.7, for reasons the Embassy need not know." },
    { id: "2d", label: "Describe, in one paragraph, the Applicant's relationship to Yukihiro Matsumoto",
      type: :long, required: true,
      help: "Literal or metaphorical responses both accepted." }
  ].freeze

  # === Section 3 · Supplementary Declarations (RANDOM POOL) ================
  # Flat list. The category groupings that previously existed were just
  # organizational scaffolding — the live system draws from this pool
  # without regard to source category.
  RANDOM_POOL = [
    { id: "3a01", type: :long, label: "What's a bug that made you question your entire existence?" },
    { id: "3a02", type: :long, label: "What's something you confidently pushed that absolutely should not have been pushed?" },
    { id: "3a03", type: :long, label: "What's your \"this worked and I don't know why\" moment?" },
    { id: "3a04", type: :long, label: "What's the most cursed piece of code you've ever written?" },
    { id: "3a05", type: :long, label: "What's a problem you solved in the worst possible way?" },
    { id: "3a06", type: :long, label: "What's something simple that took you far too long to figure out?" },
    { id: "3a07", type: :long, label: "What's your most recent \"I hate this\" moment while coding?" },

    { id: "3b01", type: :long, label: "State your most controversial programming opinion, for the record." },
    { id: "3b02", type: :long, label: "Which \"best practice\" do you quietly ignore?" },
    { id: "3b03", type: :long, label: "What is something universally beloved that the Applicant considers overrated?" },
    { id: "3b04", type: :long, label: "What is something universally reviled that the Applicant secretly enjoys?" },
    { id: "3b05", type: :long, label: "Rails: misunderstood genius, or toxic relationship? Defend your position." },
    { id: "3b06", type: :long, label: "JavaScript: enemy, ally, or situationship?" },
    { id: "3b07", type: :long, label: "If the Applicant were permitted to delete one programming language forever, which and why?" },

    { id: "3c01", type: :long, label: "If the Applicant's codebase became sentient, would it like them?" },
    { id: "3c02", type: :short, label: "If debugging were a sanctioned sport, the Applicant's ranking would be:" },
    { id: "3c03", type: :long, label: "If the Applicant's most recent bug had a personality, describe it." },
    { id: "3c04", type: :short, label: "The Applicant may use only one Ruby method forever. Which is it?" },
    { id: "3c05", type: :long, label: "The Applicant's code is being reviewed by their past self. Describe the proceeding." },
    { id: "3c06", type: :long, label: "The Applicant deploys on Friday. Honestly: why?" },
    { id: "3c07", type: :long, label: "The Applicant wakes up and Rails is gone. Describe the Applicant's next move." },

    { id: "3d01", type: :long, label: "What first drove the Applicant to begin coding?" },
    { id: "3d02", type: :long, label: "What keeps the Applicant coding even when it's painful?" },
    { id: "3d03", type: :long, label: "Describe an \"I should quit\" moment the Applicant survived without quitting." },
    { id: "3d04", type: :long, label: "Name a non-technical influence on the Applicant's coding habits." },
    { id: "3d05", type: :long, label: "Describe the Applicant's ideal coding environment (be specific)." },
    { id: "3d06", type: :long, label: "When stuck, the Applicant does what?" },

    { id: "3e01", type: :short, label: "Describe the Applicant's coding style using only vibes." },
    { id: "3e02", type: :short, label: "State the Applicant's current developer mood." },
    { id: "3e03", type: :short, label: "What kind of bug is the Applicant, as a person?" },
    { id: "3e04", type: :short, label: "If the Applicant's workflow were a meme, what would it be?" },
    { id: "3e05", type: :short, label: "State the Applicant's \"10 tabs open, hoping one helps\" ratio." },
    { id: "3e06", type: :short, label: "How many times does the Applicant Google the same error before accepting defeat?" },

    { id: "3f01", type: :long, label: "Describe the Applicant's dream project, in the absence of time and money constraints." },
    { id: "3f02", type: :short, label: "Name something the Applicant started but never finished." },
    { id: "3f03", type: :short, label: "Name something the Applicant wishes to build but has not begun." },
    { id: "3f04", type: :short, label: "Name the most \"vibe-coded\" artifact in the Applicant's portfolio." },
    { id: "3f05", type: :long, label: "What would the Applicant build if no one could judge them for it?" },

    { id: "3g01", type: :long, label: "Has the Applicant ever declared a project \"almost done\" when it was not? Elaborate." },
    { id: "3g02", type: :long, label: "Describe the Applicant's most dramatic debugging session." },
    { id: "3g03", type: :long, label: "Name a fix the Applicant shipped that immediately broke something else." },
    { id: "3g04", type: :long, label: "Has the Applicant ever nodded through a concept they did not understand? Describe the occasion." },
    { id: "3g05", type: :short, label: "Name the Applicant's \"I'm not touching that\" file or module." },
    { id: "3g06", type: :long, label: "Describe the most chaotic workaround the Applicant has ever shipped to production." },

    { id: "3h01", type: :long, label: "Why is the Applicant really here?" },
    { id: "3h02", type: :long, label: "What is the Applicant honestly hoping to extract from this conference?" },
    { id: "3h03", type: :long, label: "State the Applicant's strategy for surviving today's social interactions." },
    { id: "3h04", type: :short, label: "How many conversations before the Applicant requires recharging?" },
    { id: "3h05", type: :short, label: "Is the Applicant here to learn, to network, or to avoid responsibilities?" },

    { id: "3i01", type: :long, label: "The Applicant deploys on Friday. Describe what follows." },
    { id: "3i02", type: :long, label: "The Applicant's code works locally but fails in production. Describe next steps." },
    { id: "3i03", type: :long, label: "The Applicant inherits a legacy Rails application. Describe the first action taken." },
    { id: "3i04", type: :long, label: "A teammate declares \"it works on my machine.\" State the Applicant's response." },
    { id: "3i05", type: :long, label: "The Applicant experiences a complete lack of motivation to code. Describe the remedy." },

    { id: "3j01", type: :select, label: "Declared number of keyboards currently owned by the Applicant",
      options: ["0", "1", "2–3", "4–6", "More than the Applicant wishes to state"] },
    { id: "3j02", type: :select, label: "Preferred test runner",
      options: ["RSpec", "Minitest", "Both, as mood dictates", "Neither; the Applicant tests in production"] },
    { id: "3j03", type: :long, label: "Describe the Applicant's most embarrassing production incident (brief)",
      help: "Names will be redacted. Scars will not." },
    { id: "3j04", type: :long, label: "State the Applicant's worst Rails upgrade narrative, in no more than three sentences." },
    { id: "3j05", type: :short, label: "If Ruby were a beverage, it would be:" },
    { id: "3j06", type: :long, label: "Has the Applicant written method_missing? If so, describe the sensation.",
      help: "Responses involving \"transcendent\" or \"regret\" will be evaluated equally." },
    { id: "3j07", type: :short, label: "Name one gem that does not spark joy" },
    { id: "3j08", type: :long, label: "Describe the Applicant's emotional relationship to the practice of pair programming." }
  ].freeze

  # === Section 4 · Attestation of Community Standing =======================
  COMMON_SECTION_4 = [
    { id: "4a",
      label: "The Applicant hereby affirms or declines each of the following. Check each that applies.",
      type: :checkbox_group, required: false,
      options: [
        "I believe debugging builds character",
        "I have questioned my life choices while coding",
        "I have said \"this should work\" (it did not)",
        "I have copied code and hoped for the best",
        "I have fixed something and broken something else",
        "I have Googled the same error more than once",
        "I have considered quitting (temporarily)"
      ] }
  ].freeze

  # === Section 5 · Affidavit of Attendance =================================
  COMMON_SECTION_5 = [
    { id: "5a",
      label: "I hereby declare that the information provided is true to the best of my knowledge and current debugging ability.",
      type: :checkbox, required: true },
    { id: "5b", label: "Date of arrival in Asheville", type: :date, required: true },
    { id: "5c", label: "Does the Applicant currently possess unreleased gems of unknown provenance?",
      type: :select, required: true,
      options: ["No", "Yes", "I plead the fifth"] },
    { id: "5d", label: "Signature of Applicant (type full legal name)",
      type: :short, required: true,
      help: "Electronic signature. Carries the same legal weight as a stamped declaration — which is to say, very little." }
  ].freeze

  # === Notary Pool =========================================================
  # Each notary asks ONE follow-up question. (The original seed had multi-prompt
  # notaries; the schema now stores a single canonical prompt per notary.)
  NOTARY_POOL = [
    { external_id: "N01", description: "Uses a different language than Ruby",
      followup_prompt: "What does the notary like about it?" },
    { external_id: "N02", description: "Has attended three (3) or more Ruby conferences",
      followup_prompt: "Which is the notary's favorite?" },
    { external_id: "N03", description: "Harbors documented resentment toward Ruby on Rails",
      followup_prompt: "State the notary's grievance." },
    { external_id: "N04", description: "Has deployed to production on today's date",
      followup_prompt: "Describe what the notary shipped." },
    { external_id: "N05", description: "Actively uses Hotwire",
      followup_prompt: "State what the notary loves about Hotwire." },
    { external_id: "N06", description: "Prefers tabs over spaces",
      followup_prompt: "State the notary's justification." },
    { external_id: "N07", description: "Has formally rage-quit JavaScript at least once",
      followup_prompt: "Describe what broke them." },
    { external_id: "N08", description: "Has consumed food on camera during a Zoom standup",
      followup_prompt: "Describe the item consumed." },
    { external_id: "N09", description: "Holds the opinion that Rails is dying",
      followup_prompt: "Summarize the notary's reasoning." },
    { external_id: "N10", description: "Believes JavaScript is, in fact, fine",
      followup_prompt: "Assess the notary's well-being." },
    { external_id: "N11", description: "Prefers monoliths to microservices",
      followup_prompt: "State the notary's justification." },
    { external_id: "N12", description: "Is new to the Ruby programming language",
      followup_prompt: "State what the notary is currently learning." },
    { external_id: "N13", description: "Maintains an interesting side project",
      followup_prompt: "Record the notary's pitch." },
    { external_id: "N14", description: "Does not code, and is present strictly for vibes",
      followup_prompt: "State the vibes the notary is seeking." },
    { external_id: "N15", description: "Has published a fully vibe-coded application to the public",
      followup_prompt: "Define \"vibe coding\" in the notary's own words." },
    { external_id: "N16", description: "Can name a Ruby method known to no one else in attendance",
      followup_prompt: "Transcribe the method and its behavior here." },
    { external_id: "N17", description: "Possesses the funniest documented bug story",
      followup_prompt: "Record the account in full." },
    { external_id: "N18", description: "Sustained the worst production incident in recent memory",
      followup_prompt: "Record the account in full." }
  ].freeze
end
