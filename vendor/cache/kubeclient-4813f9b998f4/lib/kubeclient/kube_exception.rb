# Kubernetes HTTP Exceptions
class KubeException < StandardError
  attr_reader :error_code, :message, :response

  def initialize(error_code, message, response)
    @error_code = error_code
    @message = message
    @response = response
  end

  def to_s
    'HTTP status code ' + @error_code.to_s + ', ' + @message
  end
end
