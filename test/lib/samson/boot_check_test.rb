# frozen_string_literal: true
require_relative '../../test_helper'

SingleCov.covered!

describe Samson::BootCheck do
  describe ".check" do
    describe "in regular mode" do
      it "warns about loaded models/threads/mocha in regular mode" do
        e = assert_raises(RuntimeError) { Samson::BootCheck.check }
        e.message.must_include "User"
        e.message.must_include "thread"
        e.message.must_include "mocha"
      end

      it "does not warn when everything is ok" do
        Thread.stubs(:list).returns([stub("Thread", backtrace: ['ruby_thread_local_var'])])
        Samson::BootCheck.expects(:const_defined?)
        ActiveRecord::Base.expects(:descendants).returns([])
        ActionController::Base.expects(:descendants).returns([])
        Samson::BootCheck.check
      ensure
        Thread.unstub(:list)
      end
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
        Samson::Retry.expects(:sleep).times(9)
        e = assert_raises(RuntimeError) { Samson::BootCheck.check }
        e.message.must_include "Do not use AR on the main thread"
      end
    end
  end
end
