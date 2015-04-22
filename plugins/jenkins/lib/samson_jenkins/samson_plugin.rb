module SamsonJenkins
  class Engine < Rails::Engine
  end
end

Samson::Hooks.view :stage_form, "samson_jenkins/fields"
Samson::Hooks.view :deploys_header, "samson_jenkins/deploys_header"

Samson::Hooks.callback :stage_permitted_params do
  :jenkins_job_names
end

Samson::Hooks.callback :after_deploy do |deploy|
  if deploy.status == 'succeeded' && deploy.stage.jenkins_job_names?
    deploy.stage.jenkins_job_names.to_s.split(/, ?/).map do |job_name|
      job_id = Samson::Jenkins.new(job_name, deploy).build
      attributes = {name: job_name, deploy_id: deploy.id}
      if job_id.is_a?(Fixnum)
        attributes[:jenkins_job_id] = job_id
      else
        attributes[:status] = "CANCELED"
        attributes[:error] = job_id
      end
      JenkinsJob.create!(attributes)
    end
  end
end
