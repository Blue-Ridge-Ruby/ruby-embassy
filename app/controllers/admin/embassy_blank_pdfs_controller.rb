class Admin::EmbassyBlankPdfsController < AdminController
  def new
    @default_count    = 12
    @preview_sections = FakeEmbassy.sample_questions
    @preview_serial   = "RE-0427-A"
    @preview_notary   = EmbassyQuestionsSeed::NOTARY_POOL.sample(random: Random.new(42))
  end

  def create
    @count   = (params[:count].presence || 12).to_i.clamp(1, 100)
    @serials = (0...@count).map { |i| FakeEmbassy.serial_for(i) }
  end
end
