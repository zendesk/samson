# frozen_string_literal: true

require_relative "../../test_helper"

SingleCov.covered!

describe RollbarDashboards::Client do
  let(:dashboard) do
    RollbarDashboards::Setting.create!(
      project: projects(:test),
      base_url: 'https://bingbong.gov/api/1',
      account_and_project_name: "Foo/Bar",
      read_token: '12345'
    )
  end

  describe "#top_errors" do
    let(:endpoint) do
      "#{dashboard.base_url}/reports/top_active_items?access_token=12345&hours=24&environments=production"
    end

    it 'gets top errors' do
      assert_request(:get, endpoint, to_return: {body: {result: [item: {marco: 'polo'}]}.to_json}) do
        result = RollbarDashboards::Client.new(dashboard).top_errors(hours: 24, environments: ["production"])
        result.must_equal([{marco: 'polo'}])
      end
    end

    it 'shows error if response is unsuccessful' do
      Samson::ErrorNotifier.expects(:notify)
      assert_raises Samson::Hooks::UserError do
        assert_request(:get, endpoint, to_return: {status: 400}) do
          RollbarDashboards::Client.new(dashboard).top_errors(hours: 24, environments: ["production"])
        end
      end
    end

    it 'shows error if a json parse error occurs' do
      Samson::ErrorNotifier.expects(:notify)
      assert_raises Samson::Hooks::UserError do
        assert_request(:get, endpoint, to_return: {body: '<definitely>notjson</definitely>'}) do
          RollbarDashboards::Client.new(dashboard).top_errors(hours: 24, environments: ["production"])
        end
      end
    end
  end

  describe "#create_rql_job" do
    def with(params = {})
      {
        body: {
          access_token: '12345',
          query_string: query,
          force_refresh: '1'
        }.merge(params)
      }
    end

    let(:endpoint) do
      "#{dashboard.base_url}/rql/jobs"
    end
    let(:query) { 'select * from all_the_things' }

    it 'creates a job' do
      assert_request(:post, endpoint, with: with, to_return: {body: {result: {id: 1}}.to_json}) do
        result = RollbarDashboards::Client.new(dashboard).create_rql_job(query)
        result.must_equal 1
      end
    end

    it 'shows error if response is unsuccessful' do
      Samson::ErrorNotifier.expects(:notify)
      assert_raises Samson::Hooks::UserError do
        assert_request(:post, endpoint, with: with, to_return: {status: 400}) do
          RollbarDashboards::Client.new(dashboard).create_rql_job(query)
        end
      end
    end

    it 'returns nil if an error occurs' do
      Samson::ErrorNotifier.expects(:notify)
      assert_raises Samson::Hooks::UserError do
        assert_request(:post, endpoint, with: with, to_return: {body: '<definitely>notjson</definitely>'}) do
          RollbarDashboards::Client.new(dashboard).create_rql_job(query)
        end
      end
    end
  end

  describe "#rql_job_result" do
    let(:endpoint) { "#{dashboard.base_url}/rql/job/1/result?access_token=12345" }

    it 'returns result of rql job' do
      returned = {
        result: {
          result: {
            rows: [
              [123, 'A most terrible error', 'production'],
              [456, 'A series of unfortunate errors', 'production']
            ],
            columns: ['id', 'title', 'environment']
          }
        }
      }.to_json

      expected_result = [
        {id: 123, title: 'A most terrible error', environment: 'production'},
        {id: 456, title: 'A series of unfortunate errors', environment: 'production'},
      ]

      assert_request(:get, endpoint, to_return: {body: returned}) do
        result = RollbarDashboards::Client.new(dashboard).rql_job_result(1)
        result.must_equal expected_result
      end
    end

    it 'returns nil if there are no rows returned' do
      returned = {
        result: {
          result: {
            rows: [],
            columns: ['id', 'title', 'environment']
          }
        }
      }.to_json

      assert_request(:get, endpoint, to_return: {body: returned}) do
        RollbarDashboards::Client.new(dashboard).rql_job_result(1).must_be_nil
      end
    end

    it 'shows error if response was unsuccessful' do
      Samson::ErrorNotifier.expects(:notify)
      assert_raises Samson::Hooks::UserError do
        assert_request(:get, endpoint, to_return: {status: 400}) do
          RollbarDashboards::Client.new(dashboard).rql_job_result(1)
        end
      end
    end

    it 'shows error' do
      Samson::ErrorNotifier.expects(:notify)
      assert_raises Samson::Hooks::UserError do
        assert_request(:get, endpoint, to_return: {body: '{}'}) do
          RollbarDashboards::Client.new(dashboard).rql_job_result(1)
        end
      end.message.must_equal "Failed to contact rollbar"
    end

    it 'waits for job to complete' do
      finished_job_result = {
        result: {
          result: {
            rows: [[123, 'Error', 'rain forest']],
            columns: ['occurrences', 'title', 'environment']
          }
        }
      }.to_json

      pending_job_result = {result: {result: nil}}.to_json

      expected_result = [{occurrences: 123, title: 'Error', environment: 'rain forest'}]

      client = RollbarDashboards::Client.new(dashboard)
      client.expects(:sleep).with(1)
      assert_request(:get, endpoint, to_return: [{body: pending_job_result}, {body: finished_job_result}]) do
        client.rql_job_result(1).must_equal expected_result
      end
    end

    it 'returns nil if max wait time is reached' do
      pending_job_result = {result: {result: nil}}.to_json

      client = RollbarDashboards::Client.new(dashboard)
      client.expects(:sleep).with(1).times(4)
      assert_raises Samson::Hooks::UserError do
        assert_request(:get, endpoint, to_return: Array.new(5) { {body: pending_job_result} }) do
          client.rql_job_result(1)
        end
      end.message.must_equal "Timeout retrieving RQL job 1 result"
    end
  end
end
