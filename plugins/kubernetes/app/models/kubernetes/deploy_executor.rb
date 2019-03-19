# frozen_string_literal: true
# executes a deploy and writes log to job output
# finishes when deployed pods are all "Ready"
require 'vault'

module Kubernetes
  class DeployExecutor
    if ENV['KUBE_WAIT_FOR_LIVE'] && !ENV["KUBERNETES_WAIT_FOR_LIVE"]
      raise "Use KUBERNETES_WAIT_FOR_LIVE with seconds instead of KUBE_WAIT_FOR_LIVE"
    end
    WAIT_FOR_LIVE = Integer(ENV.fetch('KUBERNETES_WAIT_FOR_LIVE', '600'))
    WAIT_FOR_PREREQUISITES = Integer(ENV.fetch('KUBERNETES_WAIT_FOR_PREREQUISITES', WAIT_FOR_LIVE))
    STABILITY_CHECK_DURATION = Integer(ENV.fetch('KUBERNETES_STABILITY_CHECK_DURATION', 1.minute))
    TICK = Integer(ENV.fetch('KUBERNETES_STABILITY_CHECK_TICK', 2.seconds))
    RESTARTED = "Restarted"

    class ResourceStatus
      attr_reader :live, :stop, :details, :role, :group, :resource
      def initialize(stop: false, live:, details:, resource:, pod:, role:, group:)
        @live = live
        @stop = stop
        @details = details
        @pod = pod
        @resource = resource
        @role = role
        @group = group
      end

      def pod?
        @pod
      end

      # TODO: use resource
      def pod
        @resource if pod?
      end
    end

    def initialize(job, output)
      @output = output
      @job = job
      @reference = job.deploy.reference
    end

    # restart_signal_handler.rb calls this to show details about all running job-executions
    # and show something that identifies the deploy
    # TODO: change to .details and call that from restart_signal_handler and job_execution
    def pid
      "Kubernetes-deploy-#{object_id}"
    end

    def pgid
      pid
    end

    def execute(*)
      verify_kubernetes_templates!
      @release = create_release

      prerequisites, deploys = @release.release_docs.partition(&:prerequisite?)

      if prerequisites.any?
        @output.puts "First deploying prerequisite ..." if deploys.any?
        return false unless deploy_and_watch(prerequisites, timeout: WAIT_FOR_PREREQUISITES)
        @output.puts "Now deploying other roles ..." if deploys.any?
      end

      if deploys.any?
        return false unless deploy_and_watch(deploys, timeout: WAIT_FOR_LIVE)
      end

      true
    end

    private

    def build_finder
      @build_finder ||= Samson::BuildFinder.new(
        @output,
        @job,
        @reference,
        build_selectors: build_selectors
      )
    end

    # check all pods and see if they are running
    # once they are running check if they are stable (for apps only, since jobs are finished and will not change)
    def wait_for_resources_to_complete(release_docs, timeout)
      waiting_for_ready = true
      wait_start_time = Time.now.to_i
      @output.puts "Waiting for pods to be created"

      loop do
        statuses = all_resource_statuses(release_docs)
        if statuses.none?(&:pod?)
          @output.puts "No pods were created"
          return success, statuses
        end

        ready_statuses, not_ready_statuses = statuses.partition(&:live)
        too_many_not_ready = (not_ready_statuses.size > allowed_not_ready(statuses.size))

        if waiting_for_ready
          print_statuses(statuses)
          if too_many_not_ready
            if stopped = not_ready_statuses.select(&:stop).presence
              unstable!('one or more resources failed', stopped)
              return false, statuses
            elsif (Time.now.to_i - wait_start_time) > timeout
              @output.puts "TIMEOUT, pods took too long to get live"
              return false, statuses
            end
          elsif ready_statuses.all? { |s| !s.pod? || s.pod.completed? }
            return success, statuses
          else
            @output.puts "READY, starting stability test"
            waiting_for_ready = false
            wait_start_time = Time.now.to_i
          end
        else
          if too_many_not_ready
            print_statuses(statuses)
            unstable!('one or more resources failed', not_ready_statuses)
            return false, statuses
          else
            remaining = [wait_start_time + STABILITY_CHECK_DURATION - Time.now.to_i, 0].max
            @output.puts "Testing for stability: #{remaining}s"
            return success, statuses if stable?(remaining)
          end
        end

        sleep TICK
      end
    end

    # test hook
    def stable?(remaining)
      remaining == 0
    end

    def all_resource_statuses(release_docs)
      pods = fetch_pods
      release_docs.flat_map { |release_doc| resource_statuses(pods, release_doc) }
    end

    # efficient pod fetching by querying once per cluster instead of once per deploy group
    def fetch_pods
      @release.clients.flat_map do |client, query|
        pods = SamsonKubernetes.retry_on_connection_errors { client.get_pods(query).fetch(:items) }
        pods.map! { |p| Kubernetes::Api::Pod.new(p, client: client) }
      end
    end

    def show_logs_on_deploy_if_requested(statuses)
      pods = statuses.map(&:pod).compact.select { |p| p.annotations[:'samson/show_logs_on_deploy'] == 'true' }
      log_end = Time.now # here to be consistent for all pods
      pods.each { |pod| print_pod_details(pod, log_end, events: false) }
    rescue StandardError
      info = ErrorNotifier.notify($!, sync: true)
      @output.puts "Error showing logs: #{info}"
    end

    def show_failure_cause(release_docs, statuses)
      release_docs.each { |doc| print_resource_events(doc) }
      log_end_time = Integer(ENV['KUBERNETES_LOG_TIMEOUT'] || '20').seconds.from_now
      debug_pods = statuses.reject(&:live).select(&:pod).group_by(&:role).map { |_, g| g.first.pod }
      debug_pods.each do |pod|
        print_pod_details(pod, log_end_time, events: true)
      end
    rescue
      info = ErrorNotifier.notify($!, sync: true)
      @output.puts "Error showing failure cause: #{info}"
    ensure
      @output.puts(
        "Debug: disable 'Rollback on failure' when deploying and use 'kubectl describe pod <name>' on failed pods"
      )
    end

    def print_pod_details(pod, log_end_time, events:)
      @output.puts "\n#{pod_identifier(pod)}:"
      if events
        print_pod_events(pod)
        @output.puts
      end
      print_pod_logs(pod, log_end_time)
      @output.puts "\n------------------------------------------\n"
    end

    def pod_identifier(pod)
      "#{deploy_group_for_pod(pod).name} pod #{pod.name}"
    end

    # show why container failed to boot
    def print_pod_logs(pod, end_time)
      @output.puts "LOGS:"

      containers_names = (pod.containers + pod.init_containers).map { |c| c.fetch(:name) }.uniq
      containers_names.each do |container_name|
        @output.puts "Container #{container_name}" if containers_names.size > 1

        # Display the first and last n_lines of the log
        max = Integer(ENV['KUBERNETES_LOG_LINES'] || '50')
        lines = (pod.logs(container_name, end_time) || "No logs found").split("\n")
        lines = lines.first(max / 2) + ['...'] + lines.last(max / 2) if lines.size > max
        lines.each { |line| @output.puts "  #{line}" }
      end
    end

    # show what happened at the resource level ... need uid to avoid showing previous events
    def print_resource_events(doc)
      doc.resources.each do |resource|
        next unless resource.resource
        events = Kubernetes::EventReader.events(doc.deploy_group.kubernetes_cluster.client('v1'), resource.resource)
        next if events.none?
        @output.puts "RESOURCE EVENTS #{resource.namespace}.#{resource.name}:"
        print_events(events)
      end
    end

    # show what happened in kubernetes internally since we might not have any logs
    # reloading the events so we see things added during+after pod restart
    # not re-printing the name+namespace since we do that above already
    def print_pod_events(pod)
      @output.puts "POD EVENTS:"
      print_events(pod.events(reload: true))
    end

    def print_events(events)
      groups = events.group_by { |e| [e[:type], e[:reason], (e[:message] || "").split("\n").sort] }
      groups.each do |_, event_group|
        count = event_group.sum { |e| e[:count] }
        counter = " x#{count}" if count != 1
        e = event_group.first
        @output.puts "  #{e[:type]} #{e[:reason]}: #{e[:message]}#{counter}"
      end
    end

    def unstable!(reason, bad_resource_statuses)
      @output.puts "UNSTABLE: #{reason}"
      bad_resource_statuses.select(&:resource).each do |status|
        # TODO: resource needs deploy group too
        name = status.pod? ? pod_identifier(status.pod) : status.resource.dig(:metadata, :name)
        @output.puts "  #{name}: #{status.details}"
      end
    end

    def resource_statuses(pods, release_doc)
      group = release_doc.deploy_group
      role = release_doc.kubernetes_role

      resource_statuses = release_doc.resources.map do |resource|
        res = resource.resource
        template = resource.instance_variable_get(:@template)
        kind = template.fetch(:kind)
        next if kind == "Pod" # handled via pod_statuses
        if !res
          {live: false, stop: true, details: "Missing resource", resource: {kind: kind}, pod: false}
        else
          events = Kubernetes::EventReader.events(release_doc.deploy_group.kubernetes_cluster.client('v1'), res)
          if events.any? { |e| e.fetch(:type) != 'Normal' }
            {live: false, stop: true, details: "#{kind} Error event", resource: res, pod: false}
          else
            {live: true, details: "#{kind} Created", resource: res, pod: false}
          end
        end
      end.compact

      pods = pods.select { |pod| pod.role_id == role.id && pod.deploy_group_id == group.id }
      pod_statuses = Array.new(release_doc.desired_pod_count).each_with_index.map do |_, i|
        if !(pod = pods[i])
          {live: false, details: "Missing", resource: nil, pod: true}
        elsif pod.restarted?
          {live: false, stop: true, details: "Restarted", resource: pod, pod: true}
        elsif pod.failed?
          {live: false, stop: true, details: "Failed", resource: pod, pod: true}
        elsif release_doc.prerequisite? ? pod.completed? : pod.live?
          {live: true, details: "Live", resource: pod, pod: true}
        elsif pod.waiting_for_resources?
          {live: false, details: "Waiting for resources (#{pod.phase}, #{pod.reason})", resource: pod, pod: true}
        elsif pod.events_indicate_failure?
          {live: false, stop: true, details: "Error event", resource: pod, pod: true}
        else
          {live: false, details: "Waiting (#{pod.phase}, #{pod.reason})", resource: pod, pod: true}
        end
      end

      # If a role is autoscaled, there is a chance pods can be deleted during a deployment.
      # Sort them by "most alive" and use the first one, so we ensure at least one pods works.
      if role.autoscaled?
        pod_statuses.each { |s| s[:details] += " (autoscaled role, only showing one pod)" }
        pod_statuses.sort_by!(&method(:pod_liveliness)).slice!(1..-1)
      end

      (resource_statuses + pod_statuses).map do |status|
        ResourceStatus.new(status.merge!(role: role.name, group: group.name))
      end
    end

    def pod_liveliness(status_hash)
      if status_hash[:live]
        -1
      elsif status_hash[:stop]
        1
      else
        0
      end
    end

    def print_statuses(statuses)
      return if @last_status_output && @last_status_output > 10.seconds.ago

      @last_status_output = Time.now
      @output.puts "Deploy status:"
      statuses.group_by(&:group).each do |group, statuses|
        statuses.each do |status|
          @output.puts "  #{group} #{status.role}: #{status.details}"
        end
      end
    end

    def rollback(release_docs)
      release_docs.each do |release_doc|
        begin
          if release_doc.blue_green_color
            # NOTE: service is not rolled back since it was not changed during deploy
            delete_blue_green_resources(release_doc)
          else
            puts_action(release_doc.previous_resources.any? ? 'Rolling back' : 'Deleting', release_doc)
            release_doc.revert
          end
        rescue # ... still show events and logs if somehow the rollback fails
          @output.puts "FAILED: #{$!.message}"
        end
      end
    end

    def puts_action(action, release_doc)
      blue_green = " #{release_doc.blue_green_color.upcase} resources for" if release_doc.blue_green_color
      @output.puts "#{action}#{blue_green} #{release_doc.deploy_group.name} role #{release_doc.kubernetes_role.name}"
    end

    # create a release, storing all the configuration
    def create_release
      release = Kubernetes::Release.create_release(
        builds: build_finder.ensure_succeeded_builds,
        deploy: @job.deploy,
        grouped_deploy_group_roles: grouped_deploy_group_roles,
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

    def grouped_deploy_group_roles
      @grouped_deploy_group_roles ||= begin
        ignored_role_ids = @job.deploy.stage.kubernetes_roles.where(ignored: true).pluck(:kubernetes_role_id)
        deploy_group_roles = Kubernetes::DeployGroupRole.where(
          project_id: @job.project_id,
          deploy_group: @job.deploy.stage.deploy_groups.map(&:id)
        ).where.not(kubernetes_role_id: ignored_role_ids)

        # roles that exist in the repo for this sha
        roles_present_in_repo = Kubernetes::Role.configured_for_project(@job.project, @job.commit).
          reject { |role| ignored_role_ids.include?(role.id) }

        # check that all roles have a matching deploy_group_role
        # and all roles are configured
        errors = []
        groups = @job.deploy.stage.deploy_groups.map do |deploy_group|
          group_roles = deploy_group_roles.select { |dgr| dgr.deploy_group_id == deploy_group.id }

          # safe some sql queries during release creation
          group_roles.each do |dgr|
            dgr.deploy_group = deploy_group
            found = roles_present_in_repo.detect { |r| r.id == dgr.kubernetes_role_id }
            dgr.kubernetes_role = found if found
          end

          if missing = (group_roles.map(&:kubernetes_role) - roles_present_in_repo).presence
            files = missing.map(&:config_file).sort
            raise(
              Samson::Hooks::UserError,
              "Could not find config files for #{deploy_group.name} #{files.join(", ")} at #{@job.commit}"
            )
          end

          if extra = (roles_present_in_repo - group_roles.map(&:kubernetes_role)).presence
            roles = extra.map(&:name).join(', ')
            raise(
              Samson::Hooks::UserError,
              "Role #{roles} for #{deploy_group.name} is not configured, but in repo at #{@job.commit}. " \
              "Remove it from the repo or configure it via the stage page."
            )
          end

          group_roles
        end

        raise Samson::Hooks::UserError, errors.join("\n") if errors.any?
        groups
      end
    end

    # updates resources via kubernetes api in parallel
    def deploy(release_docs)
      resources = release_docs.flat_map do |release_doc|
        puts_action "Deploying", release_doc

        if release_doc.blue_green_color
          non_service_resources(release_doc)
        else
          release_doc.deploy_group.kubernetes_cluster # cache before threading
          [release_doc]
        end
      end
      Samson::Parallelizer.map(resources, db: true, &:deploy)
    end

    def deploy_and_watch(release_docs, timeout:)
      deploy(release_docs)
      success, statuses = wait_for_resources_to_complete(release_docs, timeout)
      if success
        if blue_green = release_docs.select(&:blue_green_color).presence
          finish_blue_green_deployment(blue_green)
        end
        show_logs_on_deploy_if_requested(statuses)
        true
      else
        show_failure_cause(release_docs, statuses)
        rollback(release_docs) if @job.deploy.kubernetes_rollback
        @output.puts "DONE"
        false
      end
    end

    def allowed_not_ready(size)
      return 0 if size == 0
      percent = Float(ENV["KUBERNETES_ALLOW_NOT_READY_PERCENT"] || "0")
      (size / 100.0) * percent
    end

    def success
      @output.puts "SUCCESS"
      true
    end

    # find deploy group without extra sql queries
    def deploy_group_for_pod(pod)
      @release.release_docs.detect { |rd| break rd.deploy_group if rd.deploy_group_id == pod.deploy_group_id }
    end

    # vary by role and not by deploy-group
    def build_selectors
      temp_release_docs.uniq(&:kubernetes_role_id).flat_map(&:build_selectors).uniq
    end

    # verify with a temp release so we can verify everything before creating a real release
    # and having to wait for docker build to finish
    def verify_kubernetes_templates!
      # - make sure each file exists
      # - make sure each deploy group has consistent labels
      grouped_deploy_group_roles.each do |deploy_group_roles|
        element_groups = deploy_group_roles.map do |deploy_group_role|
          role = deploy_group_role.kubernetes_role
          config = role.role_config_file(@job.commit)
          raise Samson::Hooks::UserError, "Error parsing #{role.config_file}" unless config
          config.elements
        end.compact
        Kubernetes::RoleValidator.validate_groups(element_groups)
      end

      # make sure each template is valid
      temp_release_docs.each(&:verify_template)
    end

    def temp_release_docs
      @temp_release_docs ||= begin
        release = Kubernetes::Release.new(
          project: @job.project,
          git_sha: @job.commit,
          git_ref: 'master',
          deploy: @job.deploy
        )
        grouped_deploy_group_roles.flatten.map do |deploy_group_role|
          Kubernetes::ReleaseDoc.new(
            kubernetes_release: release,
            deploy_group: deploy_group_role.deploy_group,
            kubernetes_role: deploy_group_role.kubernetes_role
          )
        end
      end
    end

    def finish_blue_green_deployment(release_docs)
      switch_blue_green_service(release_docs)
      previous = @release.previous_succeeded_release
      if previous && previous.blue_green_color != @release.blue_green_color
        previous.release_docs.each { |d| delete_blue_green_resources(d) }
      end
    end

    def switch_blue_green_service(release_docs)
      release_docs.each do |release_doc|
        next unless services = service_resources(release_doc).presence
        @output.puts "Switching service for #{release_doc.deploy_group.name} " \
          "role #{release_doc.kubernetes_role.name} to #{release_doc.blue_green_color.upcase}"
        services.each(&:deploy)
      end
    end

    def delete_blue_green_resources(release_doc)
      puts_action "Deleting", release_doc
      non_service_resources(release_doc).each(&:delete)
    end

    # used for blue_green deployment
    def non_service_resources(release_doc)
      release_doc.resources - service_resources(release_doc)
    end

    # used for blue_green deployment
    def service_resources(release_doc)
      release_doc.resources.select { |r| r.is_a?(Kubernetes::Resource::Service) }
    end
  end
end
