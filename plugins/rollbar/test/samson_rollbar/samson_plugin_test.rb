# frozen_string_literal: true

require_relative '../test_helper'

SingleCov.covered!

describe SamsonRollbar do
  describe 'project created callback' do
    def body
      {
        access_token: rollbar_token,
        name: project_name
      }
    end

    let(:web_base) { 'https://rollbar.com' }
    let(:endpoint) { web_base + '/api/1/projects' }
    let(:project_name) { 'foobar' }
    let(:rollbar_token) { '123' }

    with_env(ROLLBAR_ACCOUNT_TOKEN: '123')

    around { |t| Samson::Hooks.only_callbacks_for_plugin('rollbar', :project_created, &t) }

    it 'creates a rollbar project' do
      assert_request :post, endpoint, with: { body: body }, to_return: { status: 200 } do
        Samson::Hooks.fire(:project_created, project_name).must_equal ['Rollbar project created successfully']
      end
    end

    it 'gives error message if creation is unsuccessful' do
      assert_request :post, endpoint, with: { body: body }, to_return: { status: 400 } do
        error_message = 'There was a problem creating a Rollbar project. Please create one manually.'
        Samson::Hooks.fire(:project_created, project_name).must_equal [error_message]
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
