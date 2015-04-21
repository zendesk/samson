module JenkinsHelper
  def jenkins_status_panel(deploy, jenkins_job)
    mapping = {
      "SUCCESS"  => "success",
      "FAILURE"  => "danger",
      "CANCELED" => "warning",
      "ABORTED"  => "warning",
      nil        => "info"
    }

    result = {
      "SUCCESS"  => "has Passed",
      "FAILURE"  => "has Failed",
      "CANCELED" => "failed to start, Please check Jenkins job to see what went wrong",
      "ABORTED"  => "was aborted, Please go to Jenkins job to start it manually",
      nil => "is running. This can take a few minutes to finish, Please reload this page to check latest status"
    }

    jenkins_job_status = jenkins_job.status
    if !jenkins_job_status
      jenkins_job_status = Samson::Jenkins.new(jenkins_job.name, deploy).job_status(jenkins_job.jenkins_job_id)
      jenkins_job.update_attributes!(status: jenkins_job_status)
    end

    status = mapping.fetch(jenkins_job_status)
    status_message = result.fetch(jenkins_job_status)

    content = "Jenkins build #{jenkins_job.name} for #{deploy.stage.name} #{status_message}."
    content_tag :div, content.html_safe, class: "alert alert-#{status}"
  end
end
