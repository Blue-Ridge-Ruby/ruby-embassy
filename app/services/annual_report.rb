class AnnualReport
  Stat = Data.define(:question, :total_respondents, :breakdown, :extra)
  Result = Data.define(:total_passport_holders, :stats, :generated_at)

  STRUCTURED_IDS = %w[1e 1g 1h 1i 2b 5c].freeze
  CODING_YEARS_ID = "1d".freeze
  OTHER_LANGUAGE_ID = "1f".freeze
  SENTIMENTAL_VERSION_ID = "2c".freeze
  ALL_FEATURED_IDS = (STRUCTURED_IDS + [ CODING_YEARS_ID, OTHER_LANGUAGE_ID, SENTIMENTAL_VERSION_ID ]).freeze

  CODING_YEARS_QUOTES = [
    "21, old enough to party",
    "Let's just say... it's more and a 1/4 century!",
    "A bit"
  ].freeze

  LANGUAGE_NOTABLE_MENTIONS = [
    "Acts of Service",
    "Wilderness",
    "Nonviolent Communication",
    "Engrish",
    "Visual FoxPro",
    "There are other languages?"
  ].freeze

  LANGUAGE_ALIASES = {
    "js" => "JavaScript",
    "javascript" => "JavaScript",
    "ts" => "TypeScript",
    "typescript" => "TypeScript"
  }.freeze

  REFUSAL_PHRASES = [
    "i refuse", "i hold no", "n/a", "none", "no attachment", "sentimental attachments to come"
  ].freeze

  def self.build
    questions = Question.where(external_id: ALL_FEATURED_IDS).index_by(&:external_id)

    stats = {}
    STRUCTURED_IDS.each do |id|
      next unless questions[id]
      stats[id] = structured_stat(questions[id])
    end
    stats[CODING_YEARS_ID]        = coding_years_stat(questions[CODING_YEARS_ID])               if questions[CODING_YEARS_ID]
    stats[OTHER_LANGUAGE_ID]      = other_language_stat(questions[OTHER_LANGUAGE_ID])           if questions[OTHER_LANGUAGE_ID]
    stats[SENTIMENTAL_VERSION_ID] = sentimental_version_stat(questions[SENTIMENTAL_VERSION_ID]) if questions[SENTIMENTAL_VERSION_ID]

    Result.new(
      total_passport_holders: EmbassyApplication.submitted.count,
      stats: stats,
      generated_at: Time.current
    )
  end

  def self.structured_stat(question)
    answers = submitted_answers_for(question)
    breakdown =
      if question.field_type_checkbox_group?
        tally_options(answers.pluck(:value_array).compact.flatten, question.options)
      else
        tally_options(answers.pluck(:value_text).compact.reject(&:blank?), question.options)
      end
    Stat.new(question: question, total_respondents: answers.count, breakdown: breakdown, extra: {})
  end

  def self.coding_years_stat(question)
    raw = submitted_answers_for(question).pluck(:value_text).compact.reject(&:blank?)
    parsed = raw.filter_map { |v| v[/\d+/]&.to_i }.select { |n| n.between?(0, 80) }
    sorted = parsed.sort
    median = sorted.empty? ? nil : sorted[sorted.length / 2]
    Stat.new(
      question: question,
      total_respondents: raw.count,
      breakdown: {},
      extra: {
        median: median,
        min: sorted.min,
        max: sorted.max,
        parsed_count: parsed.count,
        quotes: CODING_YEARS_QUOTES
      }
    )
  end

  def self.other_language_stat(question)
    raw = submitted_answers_for(question).pluck(:value_text).compact.reject(&:blank?)
    tokens = raw.flat_map { |v| v.split(/[,\/]|\s+and\s+/i) }
                .map { |t| t.strip.gsub(/[^[:alnum:][:space:]+#.-]/, "") }
                .reject(&:blank?)
                .map { |t| LANGUAGE_ALIASES[t.downcase] || titleize_language(t) }
    counts = tokens.tally.sort_by { |_, c| -c }.first(7).to_h
    Stat.new(
      question: question,
      total_respondents: raw.count,
      breakdown: counts,
      extra: { notable_mentions: LANGUAGE_NOTABLE_MENTIONS }
    )
  end

  def self.sentimental_version_stat(question)
    raw = submitted_answers_for(question).pluck(:value_text).compact.reject(&:blank?)
    cleaned = raw.reject { |v| REFUSAL_PHRASES.any? { |p| v.downcase.include?(p) } }
    raw_versions = cleaned.filter_map { |v| v[/\d+(?:\.\d+){0,2}/] }
    normalized   = raw_versions.map { |v| v.split(".").first(2).join(".") }
    counts = normalized.tally.sort_by { |_, c| -c }.first(5).to_h
    parseable = raw_versions.filter_map { |v| Gem::Version.new(v) rescue nil }.sort
    Stat.new(
      question: question,
      total_respondents: raw.count,
      breakdown: counts,
      extra: {
        min_version: parseable.first&.to_s,
        max_version: parseable.last&.to_s
      }
    )
  end

  def self.submitted_answers_for(question)
    EmbassyApplicationAnswer
      .joins(:embassy_application)
      .where(question_id: question.id, embassy_applications: { state: "submitted" })
  end

  def self.tally_options(values, options)
    counts = values.tally
    options.each_with_object({}) { |opt, h| h[opt] = counts[opt] || 0 }
  end

  def self.titleize_language(token)
    # Preserve common all-caps or specific casings
    case token.downcase
    when "html" then "HTML"
    when "css"  then "CSS"
    when "sql"  then "SQL"
    when "c++"  then "C++"
    when "c#"   then "C#"
    when "hcl"  then "HCL"
    else
      token.split(/\s+/).map(&:capitalize).join(" ")
    end
  end

  private_class_method :structured_stat, :coding_years_stat, :other_language_stat,
                       :sentimental_version_stat, :submitted_answers_for, :tally_options,
                       :titleize_language
end
