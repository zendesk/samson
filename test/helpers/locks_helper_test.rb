require_relative '../test_helper'

SingleCov.covered!

describe LocksHelper do
  describe "#delete_lock_options" do
    it "returns the correct options" do
      choices = [
        ['Unlock in 1 hour', 3600],
        ['Unlock in 2 hours', 7200],
        ['Unlock in 4 hours', 14400],
        ['Unlock in 8 hours', 28800],
        ['Unlock in 1 day', 86400],
        ['Never', nil]
      ]
      assert_equal choices, delete_lock_options
    end
  end
end
