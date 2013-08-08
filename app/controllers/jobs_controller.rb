class JobsController < ApplicationController
  include ActionController::Live

  def execute
    project = Project.find(params[:id])

    response.headers['Content-Type'] = 'text/event-stream'

    job = project.job_histories.create!(job_params.slice(:environment))
    job.run!

    while job.running?
      job.latest_log_lines.each do |line|
        response.stream.write(line)
      end

      sleep(20)
    end
  rescue IOError
    # When the client disconnects, we'll get an IOError on write
  ensure
    response.stream.close
  end

  protected

  def job_params
    params.permit(:id, :environment)
  end
end
