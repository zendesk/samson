module Minitest::Assertions
  def assert_short_sha(value)
    assert_match /\A[0-9a-z]{6,7}\Z/, value
  end
end

module Minitest::Expectations
  infect_an_assertion :assert_short_sha, :must_be_a_short_sha, :unary
end
