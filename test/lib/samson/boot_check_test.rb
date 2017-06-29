# frozen_string_literal: true
require_relative '../../test_helper'

SingleCov.covered!

describe Samson::BootCheck do
  describe ".check" do
    it "warns about loaded models in regular mode" do
      e = assert_raises(RuntimeError) { Samson::BootCheck.check }
      e.message.must_include "should not be loaded"
    end

    describe "in server mode" do
      with_env SERVER_MODE: 'true'

      it "passes when nothing is busy" do
        ActiveRecord::Base.connection_pool.expects(:stat).times(1).returns(busy: 0)
        Samson::BootCheck.expects(:sleep).never
        Samson::BootCheck.check
      end

      it "fails when something is busy" do
        ActiveRecord::Base.connection_pool.expects(:stat).times(10).returns(busy: 1)
        Samson::BootCheck.expects(:sleep).times(9)
        e = assert_raises(RuntimeError) { Samson::BootCheck.check }
        e.message.must_include "Do not use AR on the main thread"
      end
    end
  end
end
