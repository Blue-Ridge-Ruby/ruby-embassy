class EmbassyApplicationDraw
  POOL_SIZE = 4

  def self.call(application)
    return application if application.drawn_question_ids.present?

    drawn_ids = Question
      .random_pool_active
      .left_joins(:embassy_application_answers)
      .group("questions.id")
      .order(Arel.sql("COUNT(embassy_application_answers.id) ASC, RANDOM()"))
      .limit(POOL_SIZE)
      .pluck(:external_id)

    notary = NotaryProfile
      .active
      .left_joins(:embassy_applications)
      .group("notary_profiles.id")
      .order(Arel.sql("COUNT(embassy_applications.id) ASC, RANDOM()"))
      .first

    application.update!(drawn_question_ids: drawn_ids, notary_profile: notary)
    application
  end
end
