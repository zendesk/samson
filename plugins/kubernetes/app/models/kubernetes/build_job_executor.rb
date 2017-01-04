# frozen_string_literal: true
# Execute a job that can build/push Docker images
# and write progress to the local job output.
# TODO: this reimplementes the app/models/kubernetes/resource.rb Job logic ... unify
# TODO: use digests instead of tags to be immutable
module Kubernetes
  class BuildJobExecutor
    WAIT_FOR_JOB = 5.minutes
    TICK = 3.seconds

    attr_reader :job
    delegate :id, to: :job

    def initialize(output, job:, registry:)
      @output = output
      @job = job
      @registry = registry
      raise if @registry.is_a?(Hash)
    end

    def execute!(build, project, docker_tag:, push: false, tag_as_latest: false)
      job_log = job_name = job_namespace = ""
      k8s_job = nil

      if @registry.host.blank?
        @output.puts "### Registry server should not be empty. Aborting..."
        return false, job_log
      end

      k8s_job = job_config(build, project, docker_tag: docker_tag, push: push, tag_as_latest: tag_as_latest)
      job_name = k8s_job[:metadata][:name]
      job_namespace = k8s_job[:metadata][:namespace]

      @output.puts "### Running a remote Docker build job: #{job_name}"
      success, job_log = create_and_wait_for_job(k8s_job, @output)

      message = (success ? "completed successfully" : "failed or timed out")
      @output.puts "### Remote build job #{job_name} #{message}"

      return success, job_log
    ensure
      # Jobs will still be there regardless of their statuses
      begin
        @output.puts "### Cleaning up the remote build job"
        extension_client.delete_job(job_name, job_namespace) if k8s_job
      rescue KubeException
        @output.puts "### Failed to clean up the remote build job"
      end
    end

    private

    def build_cluster
      Kubernetes::Cluster.first!
    end

    def client
      build_cluster.client
    end

    def extension_client
      build_cluster.extension_client
    end

    def build_job_config_path
      ENV['KUBE_BUILD_JOB_FILE'] || File.join(Rails.root, 'plugins', 'kubernetes', 'config', 'build_job.yml')
    end

    def fill_job_details(k8s_job, build, project, docker_tag:, push: false, tag_as_latest: false)
      # Fill in some information to easily query the job resource
      project_name = project.permalink.tr('_', '-')
      labels = { project: project_name, role: "docker-build-job" }
      k8s_job[:metadata][:name] = "#{project_name}-docker-build-#{build.id}-#{SecureRandom.hex(7)}"
      k8s_job[:metadata][:labels].update(labels)
      k8s_job[:spec][:template][:metadata][:labels].update(labels)

      # Necessary to query the pod running the job later
      k8s_job[:spec][:template][:metadata][:labels][:job_name] = k8s_job[:metadata][:name]

      # Pass all necessary information so that remote container can build the image
      container_params = {
        env: [{name: 'DOCKER_REGISTRY', value: @registry.host }],
        args: [
          project.repository_url, build.git_sha, project.docker_repo(@registry), docker_tag,
          push ? "yes" : "no",
          tag_as_latest ? "yes" : "no"
        ]
      }
      k8s_job[:spec][:template][:spec][:containers][0].update(container_params)
    end

    def job_config(build, project, docker_tag:, push: false, tag_as_latest: false)
      # Read the external config path and create a new job config instance
      contents = File.read(build_job_config_path)
      k8s_job = Kubernetes::RoleConfigFile.new(contents, build_job_config_path).job
      fill_job_details(k8s_job, build, project, docker_tag: docker_tag, push: push, tag_as_latest: tag_as_latest)
      k8s_job
    end

    def create_and_wait_for_job(k8s_job, output)
      extension_client.create_job(k8s_job.deep_symbolize_keys)
      start = Time.now
      logs = pod_name = "".dup
      job_name = k8s_job[:metadata][:name]
      job_namespace = k8s_job[:metadata][:namespace]

      # We need to loop here in case the job/pod status is not ready yet.
      # For that the API still reports the data but the job status is
      # neither success nor failure.
      loop do
        sleep TICK # Sleep a bit to wait for the server
        begin
          job = Kubernetes::Api::Job.new(
            extension_client.get_job(job_name, job_namespace)
          )
          selector = "job_name=#{job_name}".dup # A build job only has one pod
          pod = Kubernetes::Api::Pod.new(
            client.get_pods(namespace: job_namespace, label_selector: selector).first
          )
          # If the pod name for the job is unchanged from previous loops, it is likely that the pod finishes
          # but the job status is not yet updated. In this case, we will get old/duplicated logs if we start
          # a new watch stream.
          if pod_name != pod.name
            pod_name = pod.name
            client.watch_pod_log(pod.name, pod.namespace).each do |line|
              logs << line << "\n"
              output.puts line
            end
          end
        rescue StandardError
          # Something wrong happened. It is better to reset all memorized variables for logs and previous pod name.
          # Might get duplicated/old logs if the job finished successfully but the failure came from other sources.
          pod_name = logs = ""
          output.puts "### Cannot get job #{job_name}'s pod log."
        end

        return false, "" if job.failure?
        return false, "" if start + WAIT_FOR_JOB < Time.now
        return true, logs if job.complete?
      end
    end
  end
end
