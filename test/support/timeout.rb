# tests sometimes hang locally or on ci and with this we can actually debug the cause instead of just hanging forever
module TimeoutEveryTestCase
  class TestCaseTimeout < StandardError
    def message
      "Test took too long to finish, aborting. To use a debugger: disable timeouts in #{__FILE__}."
    end
  end

  def capture_exceptions(*, &block)
    super do
      rescued = false
      begin
        Timeout.timeout(5, TestCaseTimeout, &block)
      rescue TestCaseTimeout => e
        raise e if rescued
        rescued = true
        retry
      end
    end
  end
end
Minitest::Test.prepend TimeoutEveryTestCase
