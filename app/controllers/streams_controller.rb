class StreamsController < ApplicationController
  include ActionController::Live

  def show
    ActiveRecord::Base.connection_pool.release_connection

    response.headers['Content-Type'] = 'text/event-stream'
    response.headers['Cache-Control'] = 'no-cache'

    Thread.main[:streams][params[:id]] ||= []
    Thread.main[:streams][params[:id]] << response.stream

    # Heartbeat thread
    while true
      response.stream.write("data: \n\n")
      sleep(2)
    end
  rescue IOError
    # Raised on stream close
  ensure
    Thread.main[:streams][params[:id]].delete(response.stream)
    response.stream.close
  end
end
