class JobsController < ApplicationController
  include ActionController::Live

  def execute
    response.headers['Content-Type'] = 'text/event-stream'

    loop do
      response.stream.write(JSON.dump(time: Time.now))
      response.stream.write("\n")
      sleep(1)
    end
  rescue IOError
    # When the client disconnects, we'll get an IOError on write
  ensure
    response.stream.close
  end
end
