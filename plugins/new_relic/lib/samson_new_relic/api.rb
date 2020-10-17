# frozen_string_literal: true
module SamsonNewRelic
  module Api
    class << self
      def applications
        @applications ||= begin
          get('/v2/applications.json').fetch('applications').each_with_object({}) do |app, all|
            all[app.fetch('name')] = Application.new(app)
          end
        end
      end

      def metrics(application_names, initial:)
        if initial
          response(historic_metrics(application_names)).merge(historic_times: historic_times)
        else
          response(live_metrics(application_names)).merge(time: Time.now.utc.to_i)
        end
      end

      def get(path, params = {})
        response = Faraday.get("https://api.newrelic.com#{path}", params) do |request|
          request.options.open_timeout = 2
          request.headers['X-Api-Key'] = API_KEY
        end
        raise "Newrelic request to #{path} failed #{response.status}" unless response.status == 200
        JSON.parse(response.body)
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
        {applications: values, count: values.size}
      end

      def application_map(application_names)
        application_names.each_with_object({}) do |app_name, map|
          next unless app = applications[app_name]
          map[app_name] = (yield app).merge(id: app.id)
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
      def initialize(app)
        @app = app
      end

      def id
        @app.fetch('id')
      end

      def name
        @app.fetch('name')
      end

      def throughput
        @app.fetch('application_summary').fetch('throughput')
      end

      def response_time
        @app.fetch('application_summary').fetch('response_time')
      end

      def historic_response_time
        data = metric('HttpDispatcher', 'average_response_time')
        data.map! do |stamp, value|
          [stamp, (value * 1000).to_i]
        end
      end

      def historic_throughput
        metric('HttpDispatcher', 'requests_per_minute')
      end

      def reload
        @app = SamsonNewRelic::Api.get("/v2/applications/#{id}.json")
      end

      private

      def metric(metric, field)
        path = "/v2/applications/#{id}/metrics/data.json"
        start_time = Time.now.utc

        params = {
          names: [metric],
          field: field,
          begin: (start_time - 30.minutes).strftime("%Y-%m-%dT%H:%M:00Z"),
          end: start_time.strftime("%Y-%m-%dT%H:%M:00Z")
        }

        doc = SamsonNewRelic::Api.get(path, params).fetch('metric_data').fetch('metrics').first.fetch('timeslices')
        doc.map! do |m|
          [
            Time.parse(m.fetch('from')).to_i,
            m.fetch('values').fetch(field)
          ]
        end
      end
    end
  end
end
