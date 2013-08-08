class JobsController < ApplicationController
  include ActionController::Live

  def stream
    response.headers['Content-Type'] = 'text/event-stream'

    Resque.redis.redis.psubscribe(params[:id]) do |on|
      on.pmessage do |pattern, event, message|
        response.stream.write(message)
      end
    end

=begin
    AsyncRedis.psubscribe(params[:id]).callback do |data|
      response.stream.write(data)
    end.errback do |error|
      response.stream.close
    end


    loop {}
=end
  rescue IOError => e
    puts "Got IOError #{e.message}"
    puts e.backtrace.join("\n")
    # just passing through
  ensure
    response.stream.close
  end

  protected

  def job_params
    params.permit(:id, :environment)
  end
end
