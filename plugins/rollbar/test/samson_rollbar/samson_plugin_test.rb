# frozen_string_literal: true

require_relative '../test_helper'

SingleCov.covered!

describe SamsonRollbar do
  describe 'error callback' do
    let(:exception) { mock('exception') }

    only_callbacks_for_plugin :error

    it 'reports error' do
      Rollbar.expects(:warn).with(exception, foo: 'bar').returns(123)
      Samson::Hooks.fire(:error, exception, foo: 'bar').must_equal [123]
    end

    describe "with sync" do
      it 'returns url' do
        Rollbar.expects(:warn).with(exception, foo: 'bar').returns(uuid: '123')
        Samson::Hooks.fire(:error, exception, foo: 'bar', sync: true).must_equal(
          ["https://rollbar.com/instance/uuid?uuid=123"]
        )
      end

      it "ignores disabled reporter, so other reporters can show their url" do
        # the [nil] means that what other reporters send is shown to the user, see Samson::ErrorNotifier#notify
        Samson::Hooks.fire(:error, exception, foo: 'bar', sync: true).must_equal [nil]
      end
    end
  end
end
