module Kubernetes
  class Executor
    TICK = 2.seconds
    RESTARTED = "Restarted".freeze

    def initialize(output, job:)
      @output = output
      @job = job
    end

    def execute!(*)
      build = find_or_create_build
      return false if stopped?
      execution = execute_for(build)
      success = wait_to_finish(execution)
      show_failure_cause(execution) unless success
      success
    end

    def stop!(_signal)
      @stopped = true
    end

    private

    def wait_to_finish(_result)
      true
    end

    def show_failure_cause(job_docs)
      bad_pods(job_docs).each do |pod, client, deploy_group|
        @output.puts "\n#{deploy_group.name} pod #{pod.name}:"
        print_events(client, pod)
        @output.puts
        print_logs(client, pod)
      end
    end

    # logs - container fails to boot
    def print_logs(client, pod)
      @output.puts "LOGS:"

      pod.containers.map(&:name).each do |container|
        @output.puts "Container #{container}" if pod.containers.size > 1

        logs = begin
          client.get_pod_log(pod.name, pod.namespace, previous: pod.restarted?, container: container)
        rescue KubeException
          begin
            client.get_pod_log(pod.name, pod.namespace, previous: !pod.restarted?, container: container)
          rescue KubeException
            "No logs found"
          end
        end
        @output.puts logs
      end
    end

    # events - not enough cpu/ram available
    def print_events(client, pod)
      @output.puts "EVENTS:"
      events = client.get_events(
        namespace: pod.namespace,
        field_selector: "involvedObject.name=#{pod.name}"
      )
      events.uniq! { |e| e.message.split("\n").sort }
      events.each { |e| @output.puts "#{e.reason}: #{e.message}" }
    end

    def bad_pods(release)
      release.clients.flat_map do |client, query, deploy_group|
        bad_pods = fetch_pods(client, query).select { |p| p.restarted? || !p.live? }
        bad_pods.map { |p| [p, client, deploy_group] }
      end
    end

    def find_or_create_build
      build = Build.find_by_git_sha(@job.commit) || create_build
      wait_for_build(build)
      ensure_build_is_successful(build) unless @stopped
      build
    end

    def wait_for_build(build)
      if !build.docker_repo_digest && build.docker_build_job.try(:running?)
        @output.puts("Waiting for Build #{build.url} to finish.")
        loop do
          break if @stopped
          sleep TICK
          break if build.docker_build_job(:reload).finished?
        end
      end
      build.reload
    end

    def create_build
      @output.puts("Creating Build for #{@job.commit}.")
      build = Build.create!(
        git_ref: @job.commit,
        creator: @job.user,
        project: @job.project,
        label: "Automated build triggered via Job ##{@job.id}"
      )
      DockerBuilderService.new(build).run!(push: true)
      build
    end

    def ensure_build_is_successful(build)
      if build.docker_repo_digest
        @output.puts("Build #{build.url} is looking good!")
      elsif build_job = build.docker_build_job
        if build_job.succeeded?
          @output.puts("Build #{build.url} is looking good!")
        else
          raise Samson::Hooks::UserError, "Build #{build.url} is #{build_job.status}, rerun it manually."
        end
      else
        raise Samson::Hooks::UserError, "Build #{build.url} was created but never ran, run it manually."
      end
    end
  end
end
