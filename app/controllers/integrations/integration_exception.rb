class Integrations::IntegrationException < StandardError
  attr_reader :code, :message

  def initialize(code = :unprocessable_entity, message = '')
    @code = code
    @message = message
  end
end

