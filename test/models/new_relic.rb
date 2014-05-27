require_relative '../test_helper'

describe NewRelic do
  let(:account) { stub(applications: applications) }
  let(:applications) {[
    stub(id: 1, name: 'Production', account_id: 1),
    stub(id: 2, name: 'Staging', account_id: 1)
  ]}

  before do
    NewRelicApi::Account.stubs(first: account)
  end

  describe '.applications' do
    let(:apps) { NewRelic.applications }
    it 'is a hash of name -> Application' do
      apps['Production'].name.must_equal('Production')
      apps['Production'].must_be_instance_of(NewRelic::Application)
      apps.size.must_equal(2)
    end
  end

  describe '.metrics' do
    subject { NewRelic.metrics(['Production', 'Staging'], initial) }

    describe 'initial' do
      let(:initial) { true }

      before do
        NewRelic.applications.each do |_, application|
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
    end

    describe 'not initial' do
      let(:initial) { false }

      before do
        NewRelic.applications.each do |_, application|
          application.stubs(
            response_time: 100,
            throughput: 1000
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

  describe NewRelic::Application do
    subject do
      NewRelic::Application.new(stub(id: 14, name: 'Production', account_id: 1))
    end

    it 'delegates name, id' do
      subject.name.must_equal('Production')
      subject.id.must_equal(14)
    end

    describe 'thresholds' do
      before do
        subject.app.stubs(threshold_values: [
          stub(name: 'Throughput', metric_value: 1000),
          stub(name: 'Response Time', metric_value: 100),
        ])
      end

      it 'returns throughput' do
        subject.throughput.must_equal(1000)
      end

      it 'returns response_time' do
        subject.response_time.must_equal(100)
      end
    end

    describe 'historic_response_time' do
      before do
        subject.stubs(get_metric: [[1000000, 0.05]])
      end

      it 'returns 1000 * metric values' do
        subject.historic_response_time.must_equal([[1000000, 50]])
      end
    end

    describe 'historic_throughput' do
      before do
        subject.stubs(get_metric: [[1000000, 500]])
      end

      it 'returns 1000 * metric values' do
        subject.historic_throughput.must_equal([[1000000, 500]])
      end
    end

    describe 'get_metrics' do
      let(:time) { Time.now.utc }

      before do
        thirty_minutes_ago = time - (30 * 60)

        query = {
          metrics: ['metric'],
          field: 'field',
          begin: thirty_minutes_ago.strftime("%Y-%m-%dT%H:%M:00Z"),
          end: time.strftime("%Y-%m-%dT%H:%M:00Z")
        }

        @original_key, NewRelicApi.api_key = NewRelicApi.api_key, '123'

        stub_request(:get, "https://api.newrelic.com/api/v1/accounts/1/applications/14/data.json?#{query.to_query}").
          with(headers: { 'X-Api-Key' => '123' }).
          to_return(status: 200, body: JSON.dump([{ name: 'metric', begin: time.to_i.to_s, field: 'hello' }, { name: 'test' }]))
      end

      it 'returns proper metrics' do
        subject.get_metric('metric', 'field', time).must_equal([
          [time.to_i, 'hello']
        ])
      end
    end
  end
end
