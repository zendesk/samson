# frozen_string_literal: true
# executes a deploy and writes log to job output
# finishes when deployed pods are all "Ready"
require 'vault'

module Kubernetes
  class DeployExecutor
    if ENV['KUBE_WAIT_FOR_LIVE'] && !ENV["KUBERNETES_WAIT_FOR_LIVE"]
      raise "Use KUBERNETES_WAIT_FOR_LIVE with seconds instead of KUBE_WAIT_FOR_LIVE" # uncovered
    end
    DEFAULT_ROLLOUT_TIMEOUT = Integer(ENV.fetch('KUBERNETES_WAIT_FOR_LIVE', '600'))
    WAIT_FOR_PREREQUISITES = Integer(ENV.fetch('KUBERNETES_WAIT_FOR_PREREQUISITES', DEFAULT_ROLLOUT_TIMEOUT))
    STABILITY_CHECK_DURATION = Integer(ENV.fetch('KUBERNETES_STABILITY_CHECK_DURATION', 1.minute))
    TICK = Integer(ENV.fetch('KUBERNETES_STABILITY_CHECK_TICK', 10.seconds))
    RESTARTED = "Restarted"
    STATIC_KINDS = [
      "CustomResourceDefinition", "ConfigMap", "Role", "RoleBinding", "ClusterRole", "ClusterRoleBinding", "Namespace"
    ].freeze

    def initialize(job, output)
      @output = output
      @job = job
      @reference = job.deploy.reference
    end

    def preview_release_docs(resolve_build: true)
      verify_kubernetes_templates!
      @release = build_release(resolve_build: resolve_build)
      unless @release.valid?
        raise Samson::Hooks::UserError, "Failed to store manifests: #{@release.errors.full_messages.inspect}"
      end

      @release.release_docs
    end

    def execute(*)
      verify_kubernetes_templates!
      @release = build_release

      Kubernetes::Release.transaction do
        unless @release.save
          raise Samson::Hooks::UserError, "Failed to store manifests: #{@release.errors.full_messages.inspect}"
        end

        # save which builds were used in this deploy
        @job.deploy.builds = @release.builds
      end

      prerequisites, deploys = @release.release_docs.partition(&:prerequisite?)

      if prerequisites.any?
        @output.puts "First deploying prerequisite ..." if deploys.any?
        return false unless deploy_and_watch(prerequisites, timeout: WAIT_FOR_PREREQUISITES)
        @output.puts "Now deploying other roles ..." if deploys.any?
      end

      if deploys.any?
        timeout = @job.project.kubernetes_rollout_timeout || DEFAULT_ROLLOUT_TIMEOUT
        return false unless deploy_and_watch(deploys, timeout: timeout)
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

    # check all resources and see if they are working
    # once they are working check if they are stable (for apps only, since jobs are finished and will not change)
    def wait_for_resources_to_complete(release_docs, timeout)
      waiting_for_ready = true
      wait_start_time = Time.now.to_i
      @output.puts "Waiting for resources to come up" unless release_docs.all?(&:delete_resource)

      loop do
        statuses = resource_statuses(release_docs)
        pod_statuses, non_pod_statuses = statuses.partition { |s| s.kind == "Pod" }
        display_statuses = pod_statuses + non_pod_statuses.reject(&:live) # show what is interesting
        not_ready = too_many_not_ready(statuses)

        if waiting_for_ready # readiness phase
          print_statuses("Deploy status:", display_statuses, exact: false) if display_statuses.any?

          if not_ready
            if failed = too_many_failed(statuses)
              print_statuses("UNSTABLE, resources failed:", failed, exact: true)
              return false, statuses
            elsif time_left(wait_start_time, timeout) == 0
              @output.puts "TIMEOUT, pods took too long to get live"
              return false, statuses
            else # rubocop:disable Style/EmptyElse
              # keep waiting for more ready
            end
          elsif statuses.select(&:live).all?(&:finished)
            return success, statuses
          else
            @output.puts "READY, starting stability test"
            waiting_for_ready = false
            wait_start_time = Time.now.to_i
          end
        else # stability phase
          if not_ready
            if failed = too_many_failed(statuses)
              print_statuses("UNSTABLE, resources failed:", failed, exact: true)
            else
              print_statuses("UNSTABLE, resources not ready:", not_ready, exact: true)
            end
            return false, statuses
          else
            remaining = time_left(wait_start_time, STABILITY_CHECK_DURATION)
            @output.puts "Testing for stability: #{remaining}s remaining"
            return success, statuses if remaining == 0
          end
        end

        sleep TICK
      end
    end

    # test hook
    def time_left(start, timeout)
      [start + timeout - Time.now.to_i, 0].max
    end

    def resource_statuses(release_docs)
      non_pod_statuses = release_docs.flat_map do |doc|
        # do not report on the status when we are about to delete
        next [] if doc.delete_resource

        resources = doc.resources.dup

        # ignore pods since we report on them via pod_statuses
        resources.reject! { |r| r.is_a?(Kubernetes::Resource::Pod) }

        # ignore static things we don't need to check events for
        resources.reject! { |r| STATIC_KINDS.include?(r.kind) }

        resources.map! do |resource|
          ResourceStatus.new(
            resource: resource.template, # avoid extra fetches and show events when create failed
            kind: resource.kind,
            role: doc.kubernetes_role,
            deploy_group: doc.deploy_group,
            start: @deploy_start_time
          )
        end.each(&:check)
      end

      pods = fetch_grouped(:pods, 'v1')

      # Pods that get OutOfcpu/OutOfmemory will be marked as Failed.
      # Scheduler will create a replacement pod. Need to ignore Failed pods when reporting statuses.
      pods.reject! { |p| p.dig(:status, :phase) == 'Failed' && p.dig(:spec, :restartPolicy) != 'Never' }

      replica_sets = fetch_replica_sets(release_docs)
      non_pod_statuses +
        release_docs.flat_map do |release_doc|
          replica_set_statuses(replica_sets, release_doc) + pod_statuses(pods, release_doc)
        end
    end

    # efficient fetching by querying once per cluster/namespace instead of once per deploy group and role
    # NOTE: finds pods of prerequisite during actual rollout
    def fetch_grouped(type, version)
      @release.clients(version).flat_map do |client, query|
        SamsonKubernetes.retry_on_connection_errors { client.send("get_#{type}", query).fetch(:items) }
      end
    end

    # efficient way to get all ReplicaSets since they often have errors when pods cannot come up
    # ideally we'd fetch all resources that are owned by the resources we deployed, but that's much harder
    def fetch_replica_sets(release_docs)
      if release_docs.any? { |rd| rd.resource_template.any? { |r| r[:kind] == "Deployment" } }
        fetch_grouped(:replica_sets, 'apps/v1')
      else
        [] # save time
      end
    end

    def show_logs_on_deploy_if_requested(statuses)
      statuses = statuses.select { |s| s.kind == "Pod" && s.resource }

      logging = statuses.select { |s| s.resource.dig(:metadata, :annotations, :'samson/show_logs_on_deploy') == 'true' }
      if @job.deploy.stage.kubernetes_sample_logs_on_success
        logging += statuses.group_by(&:role).map { |_, s| s.first }
      end

      log_end = Time.now # here to be consistent for all pods
      logging.each { |status| print_logs(status, log_end) }
    rescue StandardError
      info = Samson::ErrorNotifier.notify($!, sync: true)
      @output.puts "  Error showing logs: #{info || "See samson logs for details"}"
    end

    def show_failure_cause(statuses)
      pod_statuses, non_pod_statuses = statuses.partition { |s| s.kind == "Pod" }

      # print events for non-resources
      non_pod_statuses.each { |s| print_events(s) }

      log_end_time = Integer(ENV['KUBERNETES_LOG_TIMEOUT'] || '20').seconds.from_now

      sample_pod_statuses = pod_statuses.
        reject(&:live). # do not debug working ones
        select(&:resource). # cannot show anything if we don't know the name
        sort_by { |s| s.finished ? 0 : 1 }. # prefer failed over waiting
        group_by(&:role).each_value.map(&:first) # 1 per role since they should fail for similar reasons

      sample_pod_statuses.each do |status|
        print_events(status)
        print_logs(status, log_end_time) unless @job.deploy.stage.kubernetes_hide_error_logs
      end
    rescue
      info = Samson::ErrorNotifier.notify($!, sync: true)
      @output.puts "Error showing failure cause: #{info}"
    ensure
      if @job.deploy.kubernetes_rollback?
        @output.puts(
          "\nDebug: disable 'Rollback on failure' when deploying and use 'kubectl describe pod <name>' on failed pods"
        )
      end
    end

    def resource_identifier(status, exact: true)
      id = "#{status.deploy_group.name} #{status.role.name} #{status.kind}"
      if exact && name = status.resource&.dig(:metadata, :name)
        id += " #{name}"
      end
      id
    end

    # show why container failed to boot
    def print_logs(status, end_time)
      @output.puts "\n#{resource_identifier(status)} logs:"

      containers_names = status.pod.container_names
      containers_names.each do |container_name|
        @output.puts "Container #{container_name}" if containers_names.size > 1

        # Display the first and last n_lines of the log
        max = Integer(ENV['KUBERNETES_LOG_LINES'] || '50')
        lines = (status.pod.logs(container_name, end_time) || "No logs found").split("\n")
        lines = lines.first(max / 2) + ['...'] + lines.last(max / 2) if lines.size > max
        lines.each { |line| @output.puts "  #{line}" }
      end
    end

    def sum_event_group(event_group)
      event_group.sum { |e| e.fetch(:count, 0) }
    end

    # show what happened in kubernetes internally since we might not have any logs
    # reloading the events so we see things added during+after pod restart
    def print_events(status)
      return unless events = status.events.presence
      @output.puts "\n#{resource_identifier(status)} events:"

      groups = events.group_by { |e| [e[:type], e[:reason], (e[:message] || "").split("\n").sort] }
      groups.each do |_, event_group|
        count = sum_event_group(event_group)
        counter = " x#{count}" if count != 1
        e = event_group.first
        @output.puts "  #{e[:type]} #{e[:reason]}: #{e[:message]}#{counter}"
      end
    end

    # we don't need to keep track of "missing" here since pod statuses already make the deploy wait
    def replica_set_statuses(replica_sets, release_doc)
      replica_sets = filter_resources(replica_sets, release_doc)
      build_status_for_resources replica_sets, release_doc, "ReplicaSet", expected: replica_sets.size
    end

    def pod_statuses(pods, release_doc)
      role = release_doc.kubernetes_role

      pods = filter_resources(pods, release_doc)

      # when autoscaling there might be more than min pods, so we need to check all of them to find the healthiest
      # NOTE: we should be able to remove the `role.autoscaled?` check, just keeping it to minimize blast radius
      expected =
        if role.autoscaled?
          [release_doc.desired_pod_count, pods.size].max
        else
          release_doc.desired_pod_count
        end

      statuses = build_status_for_resources(pods, release_doc, "Pod", expected: expected)

      # If a role is autoscaled, there is a chance pods can be deleted during a deployment.
      # Sort them by "most alive" and use the min ones, so we ensure at least that number of pods work.
      if role.autoscaled?
        statuses.sort_by! do |status|
          if status.live
            -1
          else
            status.finished ? 1 : 0
          end
        end
        statuses = statuses.first(release_doc.desired_pod_count)
      end

      statuses
    end

    def filter_resources(resources, release_doc)
      resources.select do |resource|
        labels = resource.dig_fetch(:metadata, :labels)
        Integer(labels.fetch(:role_id)) == release_doc.kubernetes_role_id &&
          Integer(labels.fetch(:deploy_group_id)) == release_doc.deploy_group_id
      end
    end

    def build_status_for_resources(resources, release_doc, kind, expected:)
      group = release_doc.deploy_group
      role = release_doc.kubernetes_role

      Array.new(expected) do |i|
        ResourceStatus.new(
          resource: resources[i],
          kind: kind,
          role: role,
          deploy_group: group,
          prerequisite: release_doc.prerequisite?,
          start: @deploy_start_time
        )
      end.each(&:check)
    end

    def print_statuses(message, statuses, exact:)
      @output.puts message
      lines = statuses.map do |status|
        "  #{resource_identifier(status, exact: exact)}: #{status.details}"
      end

      # for big deploys, do not print all the identical pods
      lines.group_by(&:itself).each_value do |group|
        group = ["#{group.first} x#{group.size}"] if lines.size >= 10 && group.size > 2
        group.each { |l| @output.puts l }
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
    def build_release(resolve_build: true)
      Kubernetes::Release.build_release_with_docs(
        builds: resolve_build ? build_finder.ensure_succeeded_builds : [],
        deploy: @job.deploy,
        grouped_deploy_group_roles: grouped_deploy_group_roles,
        git_sha: @job.commit,
        git_ref: @reference,
        user: @job.user,
        project: @job.project
      )
    end

    def grouped_deploy_group_roles
      @grouped_deploy_group_roles ||= begin
        ignored_role_ids = @job.deploy.stage.kubernetes_stage_roles.where(ignored: true).pluck(:kubernetes_role_id)
        deploy_groups = @job.deploy.stage.deploy_groups.to_a

        raise(Samson::Hooks::UserError, "No deploy groups are configured for this stage.") if deploy_groups.empty?

        deploy_group_roles = Kubernetes::DeployGroupRole.where(
          project_id: @job.project_id,
          deploy_group: deploy_groups.map(&:id)
        ).where.not(kubernetes_role_id: ignored_role_ids)

        # roles that exist in the repo for this sha
        roles_present_in_repo = Kubernetes::Role.
          configured_for_project(@job.project, @job.commit).
          reject { |role| ignored_role_ids.include?(role.id) }

        # check that all roles have a matching deploy_group_role and all roles are configured
        deploy_groups.map do |deploy_group|
          # fail early here, this was randomly not there, also fixes an n+1
          deploy_group.kubernetes_cluster || raise

          group_roles = deploy_group_roles.select { |dgr| dgr.deploy_group_id == deploy_group.id }

          # safe some sql queries during release creation
          group_roles.each do |dgr|
            dgr.deploy_group = deploy_group
            found = roles_present_in_repo.detect { |r| r.id == dgr.kubernetes_role_id }
            dgr.kubernetes_role = found if found
          end

          # TODO: make missing+extra work using dynamic folders by doing the roles_present_in_repo per deploy_group
          if group_roles.none? { |dgr| dgr.kubernetes_role.dynamic_folders? } &&
            missing = (group_roles.map(&:kubernetes_role) - roles_present_in_repo).presence

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
      end
    end

    # updates resources via kubernetes api in parallel
    def deploy(release_docs)
      resources = release_docs.flat_map do |release_doc|
        puts_action "Deploying", release_doc

        if release_doc.blue_green_color
          non_service_resources(release_doc)
        else
          [release_doc]
        end
      end

      # deploy each deploy-groups resources in logical order, but the deploy-groups in parallel
      # this calls #deploy_group + #deploy on ReleaseDoc or Resource objects
      resources.each { |r| r.deploy_group.kubernetes_cluster } # cache before threading
      Samson::Parallelizer.map(resources.group_by(&:deploy_group)) do |_, grouped_resources|
        grouped_resources.each(&:deploy)
      end
    end

    def deploy_and_watch(release_docs, timeout:)
      @deploy_start_time = Time.now.utc.iso8601
      deploy(release_docs)
      success, statuses = wait_for_resources_to_complete(release_docs, timeout)
      if success
        if blue_green = release_docs.select(&:blue_green_color).presence
          finish_blue_green_deployment(blue_green)
        end
        show_logs_on_deploy_if_requested(statuses)
        true
      else
        show_failure_cause(statuses)
        rollback(release_docs) if @job.deploy.kubernetes_rollback
        @output.puts "DONE"
        false
      end
    end

    def too_many_not_ready(statuses)
      too_many_matching_per_role(statuses, "KUBERNETES_ALLOW_NOT_READY_PERCENT") { |s| !s.live }
    end

    def too_many_failed(statuses)
      too_many_matching_per_role(statuses, "KUBERNETES_ALLOW_FAILED_PERCENT") { |s| !s.live && s.finished }
    end

    # @return [[<status>], nil]
    def too_many_matching_per_role(statuses, flag, &block)
      bad = statuses.select(&block) # always return full list for debugging
      pod_statuses, non_pod_statuses = statuses.partition { |s| s.kind == "Pod" }

      return bad if non_pod_statuses.any?(&block) # static failures are deadly

      percent = Float(ENV[flag] || "0")
      pod_statuses.group_by(&:role).each_value.detect do |group|
        allowed = (group.size / 100.0) * percent
        return bad if group.count(&block) > allowed
      end
    end

    def success
      @output.puts "SUCCESS"
      true
    end

    # vary by role and not by deploy-group
    def build_selectors
      temp_release_docs.uniq(&:kubernetes_role_id).flat_map(&:build_selectors).uniq
    end

    # verify with a temp release so we can verify everything before creating a real release
    # and having to wait for docker build to finish
    def verify_kubernetes_templates!
      # - make sure each file exists / valid
      # - make sure each deploy group has consistent labels
      # - only do this for one single deploy group since they are all identical
      element_groups = grouped_deploy_group_roles.first.map do |deploy_group_role|
        deploy_group_role.kubernetes_role.role_config_file(
          @job.commit, deploy_group: deploy_group_role.deploy_group
        ).elements
      end.compact
      Kubernetes::RoleValidator.validate_groups(element_groups)

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
