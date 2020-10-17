# frozen_string_literal: true
require_relative '../test_helper'

SingleCov.covered! uncovered: 1

describe SamsonNewRelic::Api do
  def stub_metric_api(field, value)
    Time.stubs(now: Time.parse('2016-01-01 00:00:00'))
    stub_request(:get, "https://api.newrelic.com/v2/applications/14/metrics/data.json?begin=2015-12-31T23:30:00Z&end=2016-01-01T00:00:00Z&field=#{field}&names%5B%5D=HttpDispatcher"). # rubocop:disable Layout/LineLength
      to_return(body: {
        metric_data: {metrics: [{timeslices: [{from: '2016-01-01 00:00:00', values: {field => value}}]}]}
      }.to_json)
  end

  let(:account) { stub(applications: applications) }
  let(:applications) do
    [
      {'id' => 1, 'name' => 'Production'},
      {'id' => 2, 'name' => 'Staging'}
    ]
  end

  with_new_relic_plugin_enabled

  describe '.applications' do
    it 'is a hash of name -> Application' do
      stub_request(:get, "https://api.newrelic.com/v2/applications.json").
        with(headers: {'X-Api-Key' => '123'}).
        to_return(body: {applications: applications}.to_json)
      apps = SamsonNewRelic::Api.applications
      apps['Production'].name.must_equal('Production')
      apps['Production'].must_be_instance_of(SamsonNewRelic::Api::Application)
      apps.size.must_equal(2)
    end
  end

  describe '.metrics' do
    before do
      apps = applications.map { |a| [a.fetch('name'), SamsonNewRelic::Api::Application.new(a)] }.to_h
      SamsonNewRelic::Api.stubs(applications: apps)
    end
    subject { SamsonNewRelic::Api.metrics(['Production', 'Staging'], initial: initial) }

    describe 'initial' do
      let(:initial) { true }

      before do
        SamsonNewRelic::Api.applications.each_value do |application|
          application.stubs(
            historic_response_time: [[1, 2], [3, 4]],
            historic_throughput: [[5, 6], [7, 8]]
          )
        end
      end

      it 'returns both applications' do
        subject[:applications].size.must_equal(2)
      end

      it 'returns historic_reponse_time' do
        app = subject[:applications]['Production']
        app[:historic_response_time].must_equal([2, 4])
      end

      it 'returns historic_throughput' do
        app = subject[:applications]['Production']
        app[:historic_throughput].must_equal([6, 8])
      end

      it 'returns last 30 minutes' do
        subject[:historic_times].size.must_equal(30)
        subject[:historic_times].first.must_equal(
          subject[:historic_times].last - (60 * 29)
        )
      end

      it 'returns accurate count' do
        subject[:count].must_equal(2)
      end

      it 'ignores apps that are in the DB but deleted from newrelic' do
        assert SamsonNewRelic::Api.applications.delete('Production')
        subject[:applications].size.must_equal(1)
      end
    end

    describe 'not initial' do
      let(:initial) { false }

      before do
        SamsonNewRelic::Api.applications.each_value do |application|
          application.stubs(
            response_time: 100,
            throughput: 1000,
            reload: nil
          )
        end
      end

      it 'returns both applications' do
        subject[:applications].size.must_equal(2)
      end

      it 'returns historic_reponse_time' do
        app = subject[:applications]['Production']
        app[:response_time].must_equal(100)
      end

      it 'returns historic_throughput' do
        app = subject[:applications]['Production']
        app[:throughput].must_equal(1000)
      end

      it 'returns time' do
        subject[:time].must_be_within_epsilon(Time.now.utc.to_i, 10)
      end

      it 'returns accurate count' do
        subject[:count].must_equal(2)
      end
    end
  end

  describe SamsonNewRelic::Api::Application do
    subject do
      SamsonNewRelic::Api::Application.new(
        'id' => 14,
        'name' => 'Production',
        'application_summary' => {
          'throughput' => 1234,
          'response_time' => 2345
        }
      )
    end

    it 'has an id' do
      subject.id.must_equal(14)
    end

    it 'has a name' do
      subject.name.must_equal('Production')
    end

    it 'has throughput' do
      subject.throughput.must_equal(1234)
    end

    it 'has response_time' do
      subject.response_time.must_equal(2345)
    end

    it 'can reload' do
      stub_request(:get, "https://api.newrelic.com/v2/applications/14.json").to_return(
        body: {
          'application_summary' => {
            'response_time' => 333
          }
        }.to_json
      )
      subject.reload
      subject.response_time.must_equal(333)
    end

    describe '#historic_response_time' do
      it 'returns 1000 * metric values' do
        stub_metric_api :average_response_time, 100
        subject.historic_response_time.must_equal([[1451606400, 100000]])
      end
    end

    describe '#historic_throughput' do
      it 'returns the metric' do
        stub_metric_api :requests_per_minute, 100
        subject.historic_throughput.must_equal([[1451606400, 100]])
      end
    end
  end
end
