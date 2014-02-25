module NewRelic
  class << self
    def applications
      @applications ||= NewRelicApi::Account.first.applications.inject({}) do |map, app|
        map[app.name] = Application.new(app)
        map
      end
    end

    def metrics(application_names, initial = false)
      if initial
        response(historic_metrics(application_names)).merge(historic_times: historic_times)
      else
        response(live_metrics(application_names)).merge(time: Time.now.utc.to_i)
      end
    end

    private

    def historic_metrics(application_names)
      application_map(application_names) do |app|
        {
          historic_response_time: app.historic_response_time.map(&:last),
          historic_throughput: app.historic_throughput.map(&:last)
        }
      end
    end

    def live_metrics(application_names)
      application_map(application_names) do |app|
        app.reload

        {
          response_time: app.response_time,
          throughput: app.throughput
        }
      end
    end

    def response(values)
      { applications: values, count: values.size }
    end

    def application_map(application_names)
      application_names.inject({}) do |map, app_name|
        app = NewRelic.applications[app_name]
        map[app_name] = (yield app).merge(id: app.id)
        map
      end
    end

    def historic_times
      time = Time.now.utc.to_i

      (0...30).inject([]) do |ary, i|
        ary.unshift(time - 60 * i)
      end
    end
  end

  class Application
    attr_reader :app
    delegate :id, :name, to: :app

    def initialize(app)
      @app = app
    end

    def throughput
      thresholds.detect {|t| t.name == "Throughput"}.metric_value
    end

    def response_time
      thresholds.detect {|t| t.name == "Response Time"}.metric_value
    end

    def get_metric(metric, field, start_time = Time.now.utc)
      url = "https://api.newrelic.com/api/v1/accounts/#{app.account_id}/applications/#{app.id}/data.json"

      query = {
        metrics: [metric],
        field: field,
        begin: (start_time - 60 * 30).strftime("%Y-%m-%dT%H:%M:00Z"),
        end: start_time.strftime("%Y-%m-%dT%H:%M:00Z")
      }

      response = Faraday.get(url, query) do |request|
        request.options.open_timeout = 2
        request.headers['X-Api-Key'] = NewRelicApi.api_key
      end

      doc = JSON.parse(response.body)

      doc.select {|m| m['name'] == metric}.map do |m|
        stamp = Time.at(m['begin'].to_i).to_i
        value = m[field]
        [stamp, value]
      end
    end

    def historic_response_time(time = Time.now.utc)
      data = get_metric('HttpDispatcher', 'average_response_time', time)

      data.map do |stamp, value|
        [stamp, (value * 1000).to_i]
      end
    end

    def historic_throughput(time = Time.now.utc, count = 0)
      get_metric('HttpDispatcher', 'requests_per_minute', time)
    end

    def reload
      @thresholds = nil
    end

    def thresholds
      @thresholds ||= app.threshold_values
    end
  end
end
