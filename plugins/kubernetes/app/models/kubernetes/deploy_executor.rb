# frozen_string_literal: true
# executes a deploy and writes log to job output
# finishes when cluster is "Ready"
require 'vault'

module Kubernetes
  class DeployExecutor
    WAIT_FOR_LIVE = ENV.fetch('KUBE_WAIT_FOR_LIVE', 10).to_i.minutes
    CHECK_STABLE = 1.minute
    TICK = 2.seconds
    RESTARTED = "Restarted"

    # TODO: this logic might be able to go directly into Pod, which would simplify the code here a bit
    class ReleaseStatus
      attr_reader :live, :stop, :details, :pod, :role, :group
      def initialize(stop: false, live:, details:, pod:, role:, group:)
        @live = live
        @stop = stop
        @details = details
        @pod = pod
        @role = role
        @group = group
      end
    end

    def initialize(output, job:, reference:)
      @output = output
      @job = job
      @reference = reference
      @build_finder = BuildFinder.new(
        @output,
        @job,
        @reference,
        images: @job.project.docker_image_building_disabled? && used_images
      )
    end

    # here to make restart_signal_handler happy
    def pid
      "Kubernetes-deploy-#{object_id}"
    end

    # here to make restart_signal_handler happy
    def pgid
      pid
    end

    def cancel(_signal)
      @build_finder.cancelled!
      @cancelled = true
    end

    def execute(*)
      verify_kubernetes_templates!
      @build_finder.ensure_successful_builds
      return false if cancelled?
      release = create_release

      prerequisites, deploys = release.release_docs.partition(&:prerequisite?)
      if prerequisites.any?
        @output.puts "First deploying prerequisite ..." if deploys.any?
        return false unless deploy_and_watch(release, prerequisites)
        @output.puts "Now deploying other roles ..." if deploys.any?
      end
      if deploys.any?
        return false unless deploy_and_watch(release, deploys)
      end
      true
    end

    private

    # check all pods and see if they are running
    # once they are running check if they are stable (for apps only, since jobs are finished and will not change)
    def wait_for_resources_to_complete(release, release_docs)
      raise "prerequisites should not check for stability" if @testing_for_stability
      @wait_start_time = Time.now
      stable_ticks = CHECK_STABLE / TICK
      @output.puts "Waiting for pods to be created"

      loop do
        statuses = pod_statuses(release, release_docs)
        return success if statuses.none?
        not_ready = statuses.reject(&:live)

        if @testing_for_stability
          if not_ready.any?
            print_statuses(statuses)
            unstable!('one or more pods are not live', not_ready)
            return statuses
          else
            @testing_for_stability += 1
            @output.puts "Stable #{@testing_for_stability}/#{stable_ticks}"
            return success if stable_ticks == @testing_for_stability
          end
        else
          print_statuses(statuses)
          if not_ready.any?
            if stopped = not_ready.select(&:stop).presence
              unstable!('one or more pods stopped', stopped)
              return statuses
            elsif seconds_waiting > WAIT_FOR_LIVE
              @output.puts "TIMEOUT, pods took too long to get live"
              return statuses
            end
          elsif statuses.all? { |s| s.pod.completed? }
            return success
          else
            @output.puts "READY, starting stability test"
            @testing_for_stability = 0
          end
        end

        sleep TICK
        return statuses if cancelled?
      end
    end

    def pod_statuses(release, release_docs)
      pods = fetch_pods(release)
      release_docs.flat_map { |release_doc| release_statuses(pods, release_doc) }
    end

    # efficient pod fetching by querying once per cluster instead of once per deploy group
    def fetch_pods(release)
      release.clients.flat_map do |client, query|
        pods = Vault.with_retries(KubeException, attempts: 3) { client.get_pods(query) }
        pods.map! { |p| Kubernetes::Api::Pod.new(p, client: client) }
      end
    end

    def show_failure_cause(release, release_docs, statuses)
      release_docs.each { |doc| print_resource_events(doc) }
      log_end_time = Integer(ENV['KUBERNETES_LOG_TIMEOUT'] || '20').seconds.from_now

      statuses.reject(&:live).select(&:pod).each do |status|
        pod = status.pod
        deploy_group = deploy_group_for_pod(pod, release)
        @output.puts "\n#{deploy_group.name} pod #{pod.name}:"
        print_pod_events(pod)
        @output.puts
        print_pod_logs(pod, log_end_time)
        @output.puts "\n------------------------------------------\n"
      end
    end

    # show why container failed to boot
    def print_pod_logs(pod, end_time)
      @output.puts "LOGS:"

      containers = (pod.containers + pod.init_containers).map { |c| c.fetch(:name) }
      containers.each do |container|
        @output.puts "Container #{container}" if containers.size > 1

        # Display the first and last n_lines of the log
        max = Integer(ENV['KUBERNETES_LOG_LINES'] || '50')
        lines = (pod.logs(container, end_time) || "No logs found").split("\n")
        lines = lines.first(max / 2) + ['...'] + lines.last(max / 2) if lines.size > max
        lines.each { |line| @output.puts "  #{line}" }
      end
    end

    # show what happened at the resource level ... need uid to avoid showing previous events
    def print_resource_events(doc)
      doc.resources.each do |resource|
        selector = ["involvedObject.name=#{resource.name}"]

        # do not query for nil uid ... rather show events for old+new resource when creation failed
        if uid = resource.uid
          selector << "involvedObject.uid=#{uid}"
        end

        events = doc.deploy_group.kubernetes_cluster.client.get_events(
          namespace: resource.namespace,
          field_selector: selector.join(',')
        )
        next if events.none?
        @output.puts "RESOURCE EVENTS #{resource.namespace}.#{resource.name}:"
        print_events(events)
      end
    end

    # show what happened in kubernetes internally since we might not have any logs
    def print_pod_events(pod)
      @output.puts "POD EVENTS:"
      print_events(pod.events)
    end

    def print_events(events)
      events.uniq! { |e| e.message.split("\n").sort }
      events.each do |e|
        counter = " x#{e.count}" if e.count != 1
        @output.puts "  #{e.reason}: #{e.message}#{counter}"
      end
    end

    def unstable!(reason, release_statuses)
      @output.puts "UNSTABLE: #{reason}"
      release_statuses.select(&:pod).each do |status|
        @output.puts "  #{status.pod.namespace}.#{status.pod.name}: #{status.details}"
      end
    end

    # user clicked cancel button in UI
    def cancelled?
      if @cancelled
        @output.puts "CANCELLED"
        true
      end
    end

    def release_statuses(pods, release_doc)
      group = release_doc.deploy_group
      role = release_doc.kubernetes_role

      pods = pods.select { |pod| pod.role_id == role.id && pod.deploy_group_id == group.id }

      statuses = Array.new(release_doc.desired_pod_count).each_with_index.map do |_, i|
        pod = pods[i]

        if !pod
          {live: false, details: "Missing", pod: pod}
        elsif pod.restarted?
          {live: false, stop: true, details: "Restarted", pod: pod}
        elsif pod.failed?
          {live: false, stop: true, details: "Failed", pod: pod}
        elsif release_doc.prerequisite? ? pod.completed? : pod.live?
          {live: true, details: "Live", pod: pod}
        elsif pod.events_indicate_failure?
          {live: false, stop: true, details: "Error", pod: pod}
        else
          {live: false, details: "Waiting (#{pod.phase}, #{pod.reason})", pod: pod}
        end
      end

      statuses.map do |status|
        ReleaseStatus.new(status.merge(role: role.name, group: group.name))
      end
    end

    def print_statuses(status_groups)
      return if @last_status_output && @last_status_output > 10.seconds.ago

      @last_status_output = Time.now
      @output.puts "Deploy status after #{seconds_waiting} seconds:"
      status_groups.group_by(&:group).each do |group, statuses|
        statuses.each do |status|
          @output.puts "  #{group} #{status.role}: #{status.details}"
        end
      end
    end

    def rollback(release_docs)
      release_docs.each do |release_doc|
        begin
          action = (release_doc.previous_resources.any? ? 'Rolling back' : 'Deleting')
          @output.puts "#{action} #{release_doc.deploy_group.name} role #{release_doc.kubernetes_role.name}"
          release_doc.revert
        rescue # ... still show events and logs if somehow the rollback fails
          @output.puts "FAILED: #{$!.message}"
        end
      end
    end

    # create a release, storing all the configuration
    def create_release
      release = Kubernetes::Release.create_release(
        deploy_id: @job.deploy.id,
        deploy_groups: deploy_group_configs,
        git_sha: @job.commit,
        git_ref: @reference,
        user: @job.user,
        project: @job.project
      )

      unless release.persisted?
        raise Samson::Hooks::UserError, "Failed to create release: #{release.errors.full_messages.inspect}"
      end

      @output.puts("Created kubernetes release #{release.url}")
      release
    end

    def deploy_group_configs
      @deploy_group_configs ||= begin
        # load all role configs to avoid N+1s
        roles_configs = Kubernetes::DeployGroupRole.where(
          project_id: @job.project_id,
          deploy_group: @job.deploy.stage.deploy_groups.map(&:id)
        )

        # roles that exist in the repo for this sha
        roles_present_in_repo = Kubernetes::Role.configured_for_project(@job.project, @job.commit)

        # build config for every cluster and role we want to deploy to
        errors = []
        group_configs = @job.deploy.stage.deploy_groups.map do |group|
          group_role_configs = roles_configs.select { |dgr| dgr.deploy_group_id == group.id }

          if missing = (group_role_configs.map(&:kubernetes_role) - roles_present_in_repo).presence
            files = missing.map(&:config_file).sort
            raise(
              Samson::Hooks::UserError,
              "Could not find config files for #{group.name} #{files.join(", ")} at #{@job.commit}"
            )
          end

          if extra = (roles_present_in_repo - group_role_configs.map(&:kubernetes_role)).presence
            roles = extra.map(&:name).join(', ')
            raise(
              Samson::Hooks::UserError,
              "Role #{roles} for #{group.name} is not configured, but in repo at #{@job.commit}. " \
              "Remove it from the repo or configure via it the stage page."
            )
          end

          roles = roles_present_in_repo.map do |role|
            role_config = group_role_configs.detect { |dgr| dgr.kubernetes_role_id == role.id } || raise
            {
              role: role,
              replicas: role_config.replicas,
              requests_cpu: role_config.requests_cpu,
              requests_memory: role_config.requests_memory,
              limits_cpu: role_config.limits_cpu,
              limits_memory: role_config.limits_memory
            }
          end

          {deploy_group: group, roles: roles}
        end

        raise Samson::Hooks::UserError, errors.join("\n") if errors.any?
        group_configs
      end
    end

    # updates resources via kubernetes api
    def deploy(release_docs)
      release_docs.each do |release_doc|
        @output.puts "Creating for #{release_doc.deploy_group.name} role #{release_doc.kubernetes_role.name}"
        release_doc.deploy
      end
    end

    def deploy_and_watch(release, release_docs)
      deploy(release_docs)
      result = wait_for_resources_to_complete(release, release_docs)
      if result == true
        true
      else
        show_failure_cause(release, release_docs, result)
        rollback(release_docs) if @job.deploy.kubernetes_rollback
        @output.puts "DONE"
        false
      end
    end

    def success
      @output.puts "SUCCESS"
      true
    end

    def seconds_waiting
      (Time.now - @wait_start_time).to_i if @wait_start_time
    end

    # find deploy group without extra sql queries
    def deploy_group_for_pod(pod, release)
      release.release_docs.detect { |rd| break rd.deploy_group if rd.deploy_group_id == pod.deploy_group_id }
    end

    def used_images
      Kubernetes::ReleaseDoc.new(kubernetes_release: temp_release).images
    end

    # verify with a temp release so we can verify everything before creating a real release
    # and having to wait for docker build to finish
    def verify_kubernetes_templates!
      deploy_group_configs.each do |config|
        roles = config.fetch(:roles)

        # make sure each template is valid
        roles.each do |role|
          Kubernetes::ReleaseDoc.new(
            kubernetes_release: temp_release,
            deploy_group: config.fetch(:deploy_group),
            kubernetes_role: role.fetch(:role)
          ).verify_template
        end

        # make sure each set of templates is valid
        configs = roles.map do |r|
          role = r.fetch(:role)
          config = role.role_config_file(@job.commit)
          raise Samson::Hooks::UserError, "Error parsing #{role.config_file}" unless config
          config.primary
        end.compact
        Kubernetes::RoleVerifier.verify_group(configs)
      end
    end

    def temp_release
      @temp_release ||= Kubernetes::Release.new(project: @job.project, git_sha: @job.commit, git_ref: 'master')
    end
  end
end
