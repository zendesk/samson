$(document).ready(function() {
  var newrelic_loaded = false;

  $('#newrelic-tab').on('shown.bs.tab', function(e) {
    var tab = $(e.target);

    if(!tab.data('enabled') || newrelic_loaded) {
      return;
    }

    var response_chart = null;
    var throughput_chart = null;

    var apps = {};
    var times = [];

    function rickshawSeries(series) {
      return $.map(series, function(val, i) {
        return { x: times[i], y: val };
      });
    }

    function rickshawGraph(id, series) {
      var chart = new Rickshaw.Graph({
        element: document.querySelector(id),
        width: 1040,
        height: 400,
        padding: { top: 0.05 },
        renderer: 'line',
        series: series
      });

      new Rickshaw.Graph.HoverDetail({ graph: chart });
      new Rickshaw.Graph.Axis.Time({ graph: chart });
      new Rickshaw.Graph.Axis.Y({ graph: chart, tickFormat: Rickshaw.Fixtures.Number.formatKMBT });

      return chart;
    }

    function rickshawUpdate(graph, series) {
      $.each(graph.series, function(i, graph_series) {
        graph_series.data = series[i].data;
      });
    }

    function updateNewRelic() {
      $.ajax({
        url: tab.data('url'),
        data: { initial: !newrelic_loaded },
        success: function(data, status, xhr) {
          if(!newrelic_loaded) {
            newrelic_loaded = true;
            times = data.historic_times;
          } else {
            times.push(data.time);
          }

          if($.isEmptyObject(data.applications)) {
            return;
          }

          for(var app_name in data.applications) {
            var application = apps[app_name];

            if(!application) {
              application = apps[app_name] = {};
              application.name = app_name;
              // stolen from http://stackoverflow.com/questions/1152024/best-way-to-generate-a-random-color-in-javascript
              application.color = '#'+(0x1000000+(Math.random())*0xffffff).toString(16).substr(1,6);
              application.response_time = data.applications[app_name].historic_response_time;
              application.throughput = data.applications[app_name].historic_throughput;
              application.id = data.applications[app_name].id;
            } else {
              application.response_time.push(data.applications[app_name].response_time);
              application.throughput.push(data.applications[app_name].throughput);

              if(times.length > 30) {
                application.response_time.shift();
                application.throughput.shift();
              }
            }
          }

          if(times.length > 30) {
            times.shift();
          }

          var responses = [];
          var throughputs = [];

          for(var app in apps) {
            app = apps[app];

            responses.push({
              name: app.name,
              color: app.color,
              data: rickshawSeries(app.response_time)
            });

            throughputs.push({
              name: app.name,
              color: app.color,
              data: rickshawSeries(app.throughput)
            });
          }

          if(!response_chart && !throughput_chart) {
            response_chart = rickshawGraph('#newrelic-response-time', responses);
            throughput_chart = rickshawGraph('#newrelic-throughput', throughputs);
          } else {
            rickshawUpdate(response_chart, responses);
            rickshawUpdate(throughput_chart, throughputs);
          }

          response_chart.render();
          throughput_chart.render();
        }
      });
    }

    updateNewRelic();
    setInterval(updateNewRelic, tab.data('interval'));
  });
});
