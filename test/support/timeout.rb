# tests sometimes hang locally or on ci and with this we can actually debug the cause instead of just hanging forever
module TimeoutEveryTestCase
  # travis randomly fails on some tests with this enabled
  def timeout_for_test
    ENV["CI"] ? false : 5
  end

  def capture_exceptions(*args, &block)
    if timeout_for_test == false
      super
    else
      super do
        Timeout.timeout(timeout_for_test, &block)
      end
    end
  end
end
Minitest::Test.prepend TimeoutEveryTestCase
