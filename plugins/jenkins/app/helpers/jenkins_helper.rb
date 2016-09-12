# frozen_string_literal: true
module JenkinsHelper
  def jenkins_status_panel(deploy, jenkins_job)
    mapping = {
      "SUCCESS"  => "success",
      "FAILURE"  => "danger",
      "CANCELED" => "warning",
      "ABORTED"  => "warning",
      "STARTUP_ERROR" => "warning",
      nil        => "info"
    }

    result = {
      "SUCCESS"  => "has Passed.",
      "FAILURE"  => "has Failed.",
      "CANCELED" => "was canceled, Please check Jenkins job for more details.",
      "STARTUP_ERROR" => "failed to start, Please check Jenkins job to see what went wrong.",
      "ABORTED" => "was aborted, Please go to Jenkins job to start it manually.",
      nil => "is running. This can take a few minutes to finish, Please reload this page to check latest status."
    }

    jenkins_job_status = jenkins_job.status
    jenkins_job_url = jenkins_job.url
    unless jenkins_job_status
      jenkins = Samson::Jenkins.new(jenkins_job.name, deploy)
      jenkins_job_status = jenkins.job_status(jenkins_job.jenkins_job_id) || "Unable to retrieve status from jenkins"
      jenkins_job_url = jenkins.job_url(jenkins_job.jenkins_job_id)
      attributes = {status: jenkins_job_status, url: jenkins_job_url}
      jenkins_job.update_attributes!(attributes)
    end

    if jenkins_job_status.include? ' ' # since it has whitespace, it's probably a human-readable message
      status = 'warning'
      status_message = jenkins_job_status
    else
      status = mapping.fetch(jenkins_job_status)
      status_message = result.fetch(jenkins_job_status)
    end

    content = "Jenkins build #{jenkins_job.name} for #{deploy.stage.name} #{status_message}"
    content_tag :a, href: jenkins_job_url, target: "_blank" do
      content_tag :div, content.html_safe, class: "alert alert-#{status}"
    end
  end
end
