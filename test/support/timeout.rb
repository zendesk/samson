# tests sometimes hang locally or on ci and with this we can actually debug the cause instead of just hanging forever
module TimeoutEveryTestCase
  def capture_exceptions(*args, &block)
    super do
      Timeout.timeout(5, &block)
    end
  end
end
Minitest::Test.prepend TimeoutEveryTestCase
