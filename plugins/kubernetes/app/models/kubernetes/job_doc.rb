module Kubernetes
  class JobDoc < ActiveRecord::Base

    self.table_name = 'kubernetes_job_docs'

    belongs_to :deploy_group
    belongs_to :job

    delegate :raw_template, :template_name, :kubernetes_task, to: :job
    delegate :build, :project, to: :job

    validates :deploy_group, presence: true
    validates :status, presence: true, inclusion: STATUSES

    def client
      deploy_group.kubernetes_cluster.client
    end

    # Create new client as 'Batch' API is on different path then 'v1'
    def batch_client
      deploy_group.kubernetes_cluster.batch_client
    end

    def run
      job = Kubeclient::Job.new(job_yaml.to_hash)
      if resource_running?(job)
        # batch_client.update_job job
        raise "Job already running" # TODO: Check expected behaviour
      else
        batch_client.create_job job
      end
    end

    def job_selector
      job.job_selector(deploy_group)
    end

    def kubernetes_namespace
      deploy_group.kubernetes_namespace
    end

    private

    def job_yaml
      @job_yaml ||= JobYaml.new(self)
    end

    # TODO: implement method
    def resource_running?(_resource)
      # batch_client.get_job(resource.metadata.name, resource.metadata.namespace)
      false
    rescue KubeException
      false
    end

    def parsed_config_file
      Array.wrap(Kubernetes::Util.parse_file(raw_template, template_name))
    end

    def namespace
      deploy_group.kubernetes_namespace
    end
  end
end
