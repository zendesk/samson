# frozen_string_literal: true

require_relative '../test_helper'

SingleCov.covered!

describe SamsonRollbar do
  describe 'project_permitted_params_callback' do
    it 'adds rollbar_read_token to permitted params' do
      Samson::Hooks.only_callbacks_for_plugin('rollbar', :project_permitted_params) do
        Samson::Hooks.fire(:project_permitted_params).must_equal [[:rollbar_read_token]]
      end
    end
  end

  describe 'error callback' do
    let(:exception) { mock('exception') }

    around { |t| Samson::Hooks.only_callbacks_for_plugin('rollbar', :error, &t) }

    it 'reports error' do
      Rollbar.expects(:error).with(exception, foo: 'bar').returns(123)
      Samson::Hooks.fire(:error, exception, foo: 'bar').must_equal [123]
    end

    describe "with sync" do
      it 'returns url' do
        Rollbar.expects(:error).with(exception, foo: 'bar').returns(uuid: '123')
        Samson::Hooks.fire(:error, exception, foo: 'bar', sync: true).must_equal(
          ["https://rollbar.com/instance/uuid?uuid=123"]
        )
      end

      it "ignores disabled reporter, so other reporters can show their url" do
        # the [nil] means that what other reporters send is shown to the user, see ErrorNotifier#notify
        Samson::Hooks.fire(:error, exception, foo: 'bar', sync: true).must_equal [nil]
      end
    end
  end
end
