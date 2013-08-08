class JobsController < ApplicationController
  include ActionController::Live

  def execute
    project = Project.find(params[:id])

    response.headers['Content-Type'] = 'text/event-stream'

    job = project.job_histories.active.find_or_create_by!(job_params.slice(:environment))
    job.run! unless job.running?

    while job.running?
      job.latest_log_lines.each do |line|
        response.stream.write(line)
      end
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
