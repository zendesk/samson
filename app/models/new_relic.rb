class NewRelic
  def self.applications
    @applications ||= NewRelicApi::Account.first.applications.inject({}) do |map, app|
      map[app.name] = Application.new(app)
      map
    end
  end

  class Application
    attr_accessor :app

    def initialize(app)
      @app = app
    end

    def name
      app.name
    end

    def id
      app.id
    end

    def throughput
      thresholds.detect {|t| t.name == "Throughput"}.metric_value
    end

    def response_time
      thresholds.detect {|t| t.name == "Response Time"}.metric_value
    end

    def get_metric(metric, field, start_time = Time.now, count = 0)
      url = "https://api.newrelic.com/api/v1/accounts/#{app.account_id}/applications/#{app.id}/data.json"
      url << "?metrics[]=#{metric}&field=#{field}&begin="

      from = start_time.utc - 30*60

      url << from.strftime("%Y-%m-%dT%H:%M:00Z")
      url << "&end="
      url << start_time.strftime("%Y-%m-%dT%H:%M:00Z")

      response = Faraday.get(url) do |request|
        request.headers['X-Api-Key'] = ENV['NEWRELIC_API_KEY']
      end

      data = []
      doc = JSON.parse(response.body)
      doc.select {|m| m['name'] == metric }.each do |m|
        stamp = Time.parse(m['begin']).to_i
        value = m[field]
        data << [stamp, value]
      end

      if count > 0
        data + get_metric(metric, field, from, count - 1)
      else
        data
      end
    end

    def historic_response_time(time = Time.now, count = 0)
      data = get_metric('HttpDispatcher', 'average_response_time', time, count)

      data.map do |stamp, value|
        [stamp, (value * 1000).to_i]
      end
    end

    def historic_throughput(time = Time.now, count = 0)
      get_metric('HttpDispatcher', 'requests_per_minute', time, count)
    end

    def thresholds
      @thresholds ||= app.threshold_values
    end
  end
end
