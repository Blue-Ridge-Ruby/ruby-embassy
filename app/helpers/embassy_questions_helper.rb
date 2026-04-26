module EmbassyQuestionsHelper
  MODE_LABELS = {
    "new_passport" => "New passport",
    "stamping"     => "Stamping",
    "both"         => "New passport or Stamping"
  }.freeze

  MODE_SHORT = {
    "new_passport" => "New passport",
    "stamping"     => "Stamping",
    "both"         => "New or Stamp"
  }.freeze

  EMBASSY_ETIQUETTE = [
    "Please arrive 5 minutes before your appointment time.",
    "Bring your printed application. Unprinted applications will be filled out on-site — paper only, please.",
    "Stamping appointments require an existing Ruby passport. No passport, no stamp.",
    "Photography inside the Embassy Office is permitted, but do not photograph the Stamping Apparatus.",
    "The Embassy Office is located in the Main Hall. Look for the ruby-red awning."
  ].freeze

  EMBASSY_HOURS = [
    "Saturday, May 2 · 1:00 PM – 5:00 PM",
    "Sunday, May 3 · 9:00 AM – 12:00 PM (stamping only)"
  ].freeze

  SECTION_META = {
    1 => { title: "Declaration of Ruby-ness",
           instructions: "This section establishes the Applicant's eligibility for Passport issuance pursuant to Embassy Ordinance §1.9. Complete all required fields." },
    2 => { title: "Statement of Intent & Character",
           instructions: "The Applicant is required to disclose, in their own words, certain particulars of their programming disposition. Literal or metaphorical responses both accepted. Do not leave blank." },
    3 => { title: "Supplementary Declarations",
           instructions: "The following declarations are required under Embassy Ordinance §3.14. Answers are filed in perpetuity and may be referenced at any future Embassy proceeding." },
    4 => { title: "Attestation of Community Standing",
           instructions: "Each of the following is deemed material to the Embassy's assessment of community fitness under Ordinance §4.1. The Applicant is asked to affirm or decline without reservation." },
    5 => { title: "Affidavit of Attendance",
           instructions: "Falsified statements may result in revocation of Ruby Embassy privileges for up to three (3) business gems. The Applicant signs below under penalty of Rubocop." }
  }.freeze

  def embassy_section_title(number)
    SECTION_META.dig(number, :title)
  end

  def embassy_section_instructions(number)
    SECTION_META.dig(number, :instructions)
  end

  def embassy_mode_label(mode)
    MODE_LABELS[mode.to_s] || "—"
  end

  def embassy_mode_short(mode)
    MODE_SHORT[mode.to_s] || "—"
  end

  def embassy_etiquette
    EMBASSY_ETIQUETTE
  end

  def embassy_hours
    EMBASSY_HOURS
  end
end
