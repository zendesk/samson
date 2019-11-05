# frozen_string_literal: true
module JenkinsHelper
  JENKINS_MAPPING = {
    "SUCCESS"  => "success",
    "FAILURE"  => "danger",
    "CANCELED" => "warning",
    "ABORTED"  => "warning",
    "UNSTABLE" => "warning",
    "STARTUP_ERROR" => "warning",
    nil        => "info"
  }.freeze

  JENKINS_RESULT = {
    "SUCCESS"  => "has passed.",
    "FAILURE"  => "has failed.",
    "CANCELED" => "was canceled, please check Jenkins job for more details.",
    "STARTUP_ERROR" => "failed to start, please check Jenkins job to see what went wrong.",
    "ABORTED" => "was aborted, please go to Jenkins job to start it manually.",
    "UNSTABLE" => "was unstable.",
    nil => "is running. This can take a few minutes to finish, please reload this page to check latest status."
  }.freeze

  def jenkins_status_panel(deploy, jenkins_job)
    jenkins_job_status = jenkins_job.status
    jenkins_job_url = jenkins_job.url
    unless jenkins_job_status
      jenkins = Samson::Jenkins.new(jenkins_job.name, deploy)
      jenkins_job_status = jenkins.job_status(jenkins_job.jenkins_job_id) || "Unable to retrieve status from jenkins"
      jenkins_job_url = jenkins.job_url(jenkins_job.jenkins_job_id)
      attributes = {status: jenkins_job_status, url: jenkins_job_url}
      jenkins_job.update!(attributes)
    end

    if status = JENKINS_MAPPING[jenkins_job_status]
      status_message = JENKINS_RESULT.fetch(jenkins_job_status)
    else
      status = 'warning'
      status_message = jenkins_job_status
    end

    jenkins_job_url ||= File.join(Samson::Jenkins::URL, "job", jenkins_job.name)

    content = "Jenkins build #{jenkins_job.name} for #{deploy.stage.name} #{status_message}"
    link_to jenkins_job_url, target: "_blank", rel: "noopener" do
      content_tag :div, content, class: "alert alert-#{status}"
    end
  end
end
