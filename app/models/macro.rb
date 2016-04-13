class Macro < Stage
  before_create :set_no_code_deployed

  private

  def set_no_code_deployed
    self.no_code_deployed = true
  end
end
