# Ruby Embassy — Application Question Seed Data
#
# Single source of truth for the Embassy application form. Consumed by:
#   - app/services/fake_embassy.rb (mockup rendering)
#   - db/seeds.rb (eventually, once the Question model exists)
#
# Question IDs are stable, human-readable, and printed on every form —
# the Attaché references them at the Embassy ("see box 1h"). Do not
# renumber casually.
#
# Section scope:
#   - common       — every applicant answers these
#   - random_pool  — admin-managed pool; a subset is drawn per application.
#                    Users must NEVER see scope metadata.

module EmbassyQuestionsSeed
  # === Section 1 · Declaration of Ruby-ness (COMMON) =======================
  BASIC_INFO = [
    { id: "1a", label: "Given Name (as it appears on your Tito badge)",
      type: :short, required: true,
      placeholder: "e.g., Katya" },

    { id: "1b", label: "GitHub handle",
      type: :short, required: false,
      help: "The Applicant's @handle on GitHub, where applicable." },

    { id: "1c", label: "Preferred pronouns",
      type: :short, required: false },

    { id: "1d", label: "Age, in Coding Years",
      type: :short, required: false,
      placeholder: "e.g., 9 years of Ruby, 14 years of existential dread",
      help: "For adjudication purposes only. The Embassy does not acknowledge biological years." },

    { id: "1e", label: "Today's Lottery Winnings",
      type: :short, required: false,
      placeholder: "$0 is an acceptable declaration. So is $47.12 in Coinstar.",
      help: "For audit purposes. Amounts in excess of $10M must be disclosed to the Embassy Attaché. Receipts may be requested." },

    { id: "1f", label: "Declared Ruby Proficiency",
      type: :select, required: true,
      options: [
        "Just installed it",
        "I use Ruby",
        "I fight Ruby",
        "I am Ruby"
      ] },

    { id: "1g", label: "Primary language, other than Ruby",
      type: :short, required: false,
      placeholder: "e.g., Go, Elixir, Fortran, Emotional Support" },

    { id: "1h", label: "Stated purpose of visit (select all that apply)",
      type: :checkbox_group, required: false,
      options: [ "Learning", "Networking", "Vibes", "Free coffee" ] },

    { id: "1i", label: "Most recent sentiment experienced while programming (select all that apply)",
      type: :checkbox_group, required: false,
      options: [ "Powerful", "Confused", "Betrayed", "Like a genius", "Like quitting forever" ] },

    { id: "1j", label: "Declared developer persona (select all that apply)",
      type: :checkbox_group, required: false,
      options: [
        "The Debugger",
        "The Ship-It Gremlin",
        "The Perfectionist",
        "The \"it works, don't touch it\"",
        "The Vibe Coder"
      ] }
  ].freeze

  # === Section 2 · Statement of Intent & Character (COMMON) ================
  PERSONAL_STATEMENT = [
    { id: "2a", label: "Describe the Applicant's current relationship with programming, in one sentence",
      type: :long, required: true },

    { id: "2b", label: "First Ruby release the Applicant remembers using",
      type: :select, required: false,
      options: [ "1.8.x", "1.9.x", "2.0–2.6", "2.7–3.0", "3.1+", "I refuse to answer" ] },

    { id: "2c", label: "Ruby release for which the Applicant harbors sentimental attachment",
      type: :short, required: false,
      placeholder: "e.g., 1.8.7, for reasons the Embassy need not know." },

    { id: "2d", label: "Describe, in one paragraph, the Applicant's relationship to Yukihiro Matsumoto",
      type: :long, required: true,
      help: "Literal or metaphorical responses both accepted." }
  ].freeze

  # === Section 3 · Supplementary Declarations (RANDOM POOL) ================
  # Organized into categories for the admin question bank. Draws happen
  # across the flattened pool (RANDOM_POOL). Users see only a numbered
  # section with a handful of questions; they must not infer randomization.
  RANDOM_POOL_CATEGORIES = {
    programming_reality: {
      title: "Programming Reality",
      questions: [
        { id: "3a01", type: :long,
          label: "What's a bug that made you question your entire existence?" },
        { id: "3a02", type: :long,
          label: "What's something you confidently pushed that absolutely should not have been pushed?" },
        { id: "3a03", type: :long,
          label: "What's your \"this worked and I don't know why\" moment?" },
        { id: "3a04", type: :long,
          label: "What's the most cursed piece of code you've ever written?" },
        { id: "3a05", type: :long,
          label: "What's a problem you solved in the worst possible way?" },
        { id: "3a06", type: :long,
          label: "What's something simple that took you far too long to figure out?" },
        { id: "3a07", type: :long,
          label: "What's your most recent \"I hate this\" moment while coding?" }
      ]
    },
    hot_takes: {
      title: "Hot Takes & Chaos",
      questions: [
        { id: "3b01", type: :long,
          label: "State your most controversial programming opinion, for the record." },
        { id: "3b02", type: :long,
          label: "Which \"best practice\" do you quietly ignore?" },
        { id: "3b03", type: :long,
          label: "What is something universally beloved that the Applicant considers overrated?" },
        { id: "3b04", type: :long,
          label: "What is something universally reviled that the Applicant secretly enjoys?" },
        { id: "3b05", type: :long,
          label: "Rails: misunderstood genius, or toxic relationship? Defend your position." },
        { id: "3b06", type: :long,
          label: "JavaScript: enemy, ally, or situationship?" },
        { id: "3b07", type: :long,
          label: "If the Applicant were permitted to delete one programming language forever, which and why?" }
      ]
    },
    hypotheticals: {
      title: "Hypotheticals",
      questions: [
        { id: "3c01", type: :long,
          label: "If the Applicant's codebase became sentient, would it like them?" },
        { id: "3c02", type: :short,
          label: "If debugging were a sanctioned sport, the Applicant's ranking would be:" },
        { id: "3c03", type: :long,
          label: "If the Applicant's most recent bug had a personality, describe it." },
        { id: "3c04", type: :short,
          label: "The Applicant may use only one Ruby method forever. Which is it?" },
        { id: "3c05", type: :long,
          label: "The Applicant's code is being reviewed by their past self. Describe the proceeding." },
        { id: "3c06", type: :long,
          label: "The Applicant deploys on Friday. Honestly: why?" },
        { id: "3c07", type: :long,
          label: "The Applicant wakes up and Rails is gone. Describe the Applicant's next move." }
      ]
    },
    personal: {
      title: "Personal (but still chaotic)",
      questions: [
        { id: "3d01", type: :long,
          label: "What first drove the Applicant to begin coding?" },
        { id: "3d02", type: :long,
          label: "What keeps the Applicant coding even when it's painful?" },
        { id: "3d03", type: :long,
          label: "Describe an \"I should quit\" moment the Applicant survived without quitting." },
        { id: "3d04", type: :long,
          label: "Name a non-technical influence on the Applicant's coding habits." },
        { id: "3d05", type: :long,
          label: "Describe the Applicant's ideal coding environment (be specific)." },
        { id: "3d06", type: :long,
          label: "When stuck, the Applicant does what?" }
      ]
    },
    vibe_meme: {
      title: "Vibe / Meme Energy",
      questions: [
        { id: "3e01", type: :short,
          label: "Describe the Applicant's coding style using only vibes." },
        { id: "3e02", type: :short,
          label: "State the Applicant's current developer mood." },
        { id: "3e03", type: :short,
          label: "What kind of bug is the Applicant, as a person?" },
        { id: "3e04", type: :short,
          label: "If the Applicant's workflow were a meme, what would it be?" },
        { id: "3e05", type: :short,
          label: "State the Applicant's \"10 tabs open, hoping one helps\" ratio." },
        { id: "3e06", type: :short,
          label: "How many times does the Applicant Google the same error before accepting defeat?" }
      ]
    },
    side_projects: {
      title: "Side Projects & Dreams",
      questions: [
        { id: "3f01", type: :long,
          label: "Describe the Applicant's dream project, in the absence of time and money constraints." },
        { id: "3f02", type: :short,
          label: "Name something the Applicant started but never finished." },
        { id: "3f03", type: :short,
          label: "Name something the Applicant wishes to build but has not begun." },
        { id: "3f04", type: :short,
          label: "Name the most \"vibe-coded\" artifact in the Applicant's portfolio." },
        { id: "3f05", type: :long,
          label: "What would the Applicant build if no one could judge them for it?" }
      ]
    },
    unhinged: {
      title: "Slightly Unhinged",
      questions: [
        { id: "3g01", type: :long,
          label: "Has the Applicant ever declared a project \"almost done\" when it was not? Elaborate." },
        { id: "3g02", type: :long,
          label: "Describe the Applicant's most dramatic debugging session." },
        { id: "3g03", type: :long,
          label: "Name a fix the Applicant shipped that immediately broke something else." },
        { id: "3g04", type: :long,
          label: "Has the Applicant ever nodded through a concept they did not understand? Describe the occasion." },
        { id: "3g05", type: :short,
          label: "Name the Applicant's \"I'm not touching that\" file or module." },
        { id: "3g06", type: :long,
          label: "Describe the most chaotic workaround the Applicant has ever shipped to production." }
      ]
    },
    conference: {
      title: "Conference Particulars",
      questions: [
        { id: "3h01", type: :long,
          label: "Why is the Applicant really here?" },
        { id: "3h02", type: :long,
          label: "What is the Applicant honestly hoping to extract from this conference?" },
        { id: "3h03", type: :long,
          label: "State the Applicant's strategy for surviving today's social interactions." },
        { id: "3h04", type: :short,
          label: "How many conversations before the Applicant requires recharging?" },
        { id: "3h05", type: :short,
          label: "Is the Applicant here to learn, to network, or to avoid responsibilities?" }
      ]
    },
    scenarios: {
      title: "Scenarios",
      questions: [
        { id: "3i01", type: :long,
          label: "The Applicant deploys on Friday. Describe what follows." },
        { id: "3i02", type: :long,
          label: "The Applicant's code works locally but fails in production. Describe next steps." },
        { id: "3i03", type: :long,
          label: "The Applicant inherits a legacy Rails application. Describe the first action taken." },
        { id: "3i04", type: :long,
          label: "A teammate declares \"it works on my machine.\" State the Applicant's response." },
        { id: "3i05", type: :long,
          label: "The Applicant experiences a complete lack of motivation to code. Describe the remedy." }
      ]
    },
    ruby_flavor: {
      title: "Ruby Flavor",
      questions: [
        { id: "3j01", type: :select,
          label: "Declared number of keyboards currently owned by the Applicant",
          options: [ "0", "1", "2–3", "4–6", "More than the Applicant wishes to state" ] },
        { id: "3j02", type: :select,
          label: "Preferred test runner",
          options: [ "RSpec", "Minitest", "Both, as mood dictates", "Neither; the Applicant tests in production" ] },
        { id: "3j03", type: :long,
          label: "Describe the Applicant's most embarrassing production incident (brief)",
          help: "Names will be redacted. Scars will not." },
        { id: "3j04", type: :long,
          label: "State the Applicant's worst Rails upgrade narrative, in no more than three sentences." },
        { id: "3j05", type: :short,
          label: "If Ruby were a beverage, it would be:" },
        { id: "3j06", type: :long,
          label: "Has the Applicant written method_missing? If so, describe the sensation.",
          help: "Responses involving \"transcendent\" or \"regret\" will be evaluated equally." },
        { id: "3j07", type: :short,
          label: "Name one gem that does not spark joy" },
        { id: "3j08", type: :long,
          label: "Describe the Applicant's emotional relationship to the practice of pair programming." }
      ]
    }
  }.freeze

  # Flat view of the pool — used for drawing + the admin question bank.
  RANDOM_POOL = RANDOM_POOL_CATEGORIES.flat_map { |_, cat| cat[:questions] }.freeze

  # How many pool questions each application draws.
  RANDOM_POOL_DRAWS = 5

  # === Section 4 · Attestation of Community Standing (COMMON) ==============
  COMMUNITY_ALIGNMENT = [
    { id: "4a",
      label: "The Applicant hereby affirms or declines each of the following. Check each that applies.",
      type: :checkbox_group,
      required: false,
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

  # === Section 5 · Affidavit of Attendance (COMMON) ========================
  DECLARATION = [
    { id: "5a",
      label: "I hereby declare that the information provided is true to the best of my knowledge and current debugging ability.",
      type: :checkbox, required: true },

    { id: "5b", label: "Date of arrival in Asheville",
      type: :date, required: true },

    { id: "5c", label: "Does the Applicant currently possess unreleased gems of unknown provenance?",
      type: :select, required: true,
      options: [ "No", "Yes", "I plead the fifth" ] },

    { id: "5d", label: "Signature of Applicant (type full legal name)",
      type: :short, required: true,
      help: "Electronic signature. Carries the same legal weight as a stamped declaration — which is to say, very little." }
  ].freeze

  # === Notary Requirement (PDF-only addendum) ==============================
  # The ice-breaker. One is drawn per application and appears on the
  # PRINTED form only — users must physically locate someone matching
  # the description at the Embassy and have them sign. Admins manage
  # the pool via the question bank.
  NOTARY_POOL = [
    { id: "N01", description: "Uses a different language than Ruby",
      followups: [ "What does the notary like about it?" ] },

    { id: "N02", description: "Has attended three (3) or more Ruby conferences",
      followups: [
        "Which is the notary's favorite?",
        "State the notary's rubyevents.com URL.",
        "Are you and the notary best friends on rubyevents.com yet?"
      ] },

    { id: "N03", description: "Harbors documented resentment toward Ruby on Rails",
      followups: [ "State the notary's grievance." ] },

    { id: "N04", description: "Has deployed to production on today's date",
      followups: [ "Describe what the notary shipped." ] },

    { id: "N05", description: "Actively uses Hotwire",
      followups: [
        "State what the notary loves about Hotwire.",
        "State what the notary loathes about Hotwire."
      ] },

    { id: "N06", description: "Prefers tabs over spaces",
      followups: [ "State the notary's justification." ] },

    { id: "N07", description: "Has formally rage-quit JavaScript at least once",
      followups: [ "Describe what broke them." ] },

    { id: "N08", description: "Has consumed food on camera during a Zoom standup",
      followups: [ "Describe the item consumed." ] },

    { id: "N09", description: "Holds the opinion that Rails is dying",
      followups: [ "Summarize the notary's reasoning." ] },

    { id: "N10", description: "Believes JavaScript is, in fact, fine",
      followups: [ "Assess the notary's well-being." ] },

    { id: "N11", description: "Prefers monoliths to microservices",
      followups: [
        "State the notary's justification.",
        "Assess the notary's well-being."
      ] },

    { id: "N12", description: "Is new to the Ruby programming language",
      followups: [ "State what the notary is currently learning." ] },

    { id: "N13", description: "Maintains an interesting side project",
      followups: [ "Record the notary's pitch." ] },

    { id: "N14", description: "Does not code, and is present strictly for vibes",
      followups: [ "State the vibes the notary is seeking." ] },

    { id: "N15", description: "Has published a fully vibe-coded application to the public",
      followups: [
        "Define \"vibe coding\" in the notary's own words.",
        "Name the application.",
        "State the URL.",
        "Is the application actually good? (Applicant's opinion.)",
        "Is the application actually good? (Notary's opinion.)"
      ] },

    { id: "N16", description: "Can name a Ruby method known to no one else in attendance",
      followups: [ "Transcribe the method and its behavior here." ] },

    { id: "N17", description: "Possesses the funniest documented bug story",
      followups: [ "Record the account in full." ] },

    { id: "N18", description: "Sustained the worst production incident in recent memory",
      followups: [ "Record the account in full." ] }
  ].freeze
end
