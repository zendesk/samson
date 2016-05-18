# executes a deploy and writes log to job output
# finishes when cluster is "Ready"
module Kubernetes
  class DeployExecutor
    WAIT_FOR_LIVE = 10.minutes
    CHECK_STABLE = 1.minute
    TICK = 2.seconds
    RESTARTED = "Restarted".freeze

    ReleaseStatus = Struct.new(:live, :details, :role, :group)

    def initialize(output, job:)
      @output = output
      @job = job
    end

    def pid
      "Kubernetes-deploy-#{object_id}"
    end

    def stop!(_signal)
      @stopped = true
    end

    def execute!(*_commands)
      build = find_or_create_build
      return false if stopped?
      release = create_release(build)
      ensure_service(release)
      create_deploys(release)
      success = wait_for_deploys_to_finish(release)
      show_failure_cause(release) unless success
      success
    end

    private

    def wait_for_deploys_to_finish(release)
      start = Time.now
      stable_ticks = CHECK_STABLE / TICK

      loop do
        return false if stopped?

        statuses = pod_statuses(release)

        if @testing_for_stability
          if statuses.all?(&:live)
            @testing_for_stability += 1
            @output.puts "Stable #{@testing_for_stability}/#{stable_ticks}"
            if stable_ticks == @testing_for_stability
              @output.puts "SUCCESS"
              return true
            end
          else
            print_statuses(statuses)
            unstable!
            return false
          end
        else
          print_statuses(statuses)
          if statuses.all?(&:live)
            @output.puts "READY, starting stability test"
            @testing_for_stability = 0
          elsif statuses.map(&:details).include?(RESTARTED)
            unstable!
            return false
          elsif start + WAIT_FOR_LIVE < Time.now
            @output.puts "TIMEOUT, pods took too long to get live"
            return false
          end
        end

        sleep TICK
      end
    end

    def pod_statuses(release)
      pods = release.clients.flat_map { |client, query| fetch_pods(client, query) }
      release.release_docs.flat_map { |release_doc| release_statuses(pods, release_doc) }
    end

    def fetch_pods(client, query)
      client.get_pods(query).map! { |p| Kubernetes::Api::Pod.new(p) }
    end

    def show_failure_cause(release)
      bad_pods = release.clients.flat_map do |client, query, deploy_group|
        bad_pods = fetch_pods(client, query).select { |p| p.restarted? || !p.live? }
        bad_pods.map { |p| [p, client, deploy_group] }
      end

      bad_pods.each do |pod, client, deploy_group|
        namespace = deploy_group.kubernetes_namespace
        @output.puts "\n#{deploy_group.name} pod #{pod.name}:"

        # events - not enough cpu/ram available
        @output.puts "EVENTS:"
        events = client.get_events(namespace: namespace, field_selector: "involvedObject.name=#{pod.name}")
        events.uniq! { |e| e.message.split("\n").sort }
        events.each { |e| @output.puts "#{e.reason}: #{e.message}" }

        # logs - container fails to boot
        @output.puts "\nLOGS:"
        logs = begin
          client.get_pod_log(pod.name, namespace, previous: pod.restarted?)
        rescue KubeException
          "No logs found"
        end
        @output.puts logs
      end
    end

    def unstable!
      @output.puts "UNSTABLE - service is restarting"
    end

    def stopped?
      if @stopped
        @output.puts "STOPPED"
        true
      end
    end

    def release_statuses(pods, release_doc)
      group = release_doc.deploy_group
      role = release_doc.kubernetes_role

      pods = pods.select { |pod| pod.role_id == role.id && pod.deploy_group_id == group.id }

      statuses = if pods.empty?
        [[false, "Missing"]]
      else
        pods.map do |pod|
          if pod.live?
            if pod.restarted?
              [false, RESTARTED]
            else
              [true, "Live"]
            end
          else
            [false, "Waiting (#{pod.phase}, not Ready)"]
          end
        end
      end

      statuses.map do |live, details|
        ReleaseStatus.new(live, details, role.name, group.name)
      end
    end

    def print_statuses(status_groups)
      status_groups.group_by(&:group).each do |group, statuses|
        @output.puts "#{group}:"
        statuses.each do |status|
          @output.puts "  #{status.role}: #{status.details}"
        end
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
        label: "Automated build triggered via Deploy ##{@job.deploy.id}"
      )
      DockerBuilderService.new(build).run!(push: true)
      build
    end

    def ensure_build_is_successful(build)
      if build.docker_repo_digest
        @output.puts("Build #{build.url} is looking good!")
      elsif build_job = build.docker_build_job
        raise Samson::Hooks::UserError, "Build #{build.url} is #{build_job.status}, rerun it manually."
      else
        raise Samson::Hooks::UserError, "Build #{build.url} was created but never ran, run it manually."
      end
    end

    # create a release, storing all the configuration
    def create_release(build)
      # find role configs to avoid N+1s
      roles_configs = Kubernetes::DeployGroupRole.where(
        project_id: @job.project_id,
        deploy_group: @job.deploy.stage.deploy_groups.map(&:id)
      )

      # get all the roles that are configured for this sha
      configured_roles = Kubernetes::Role.configured_for_project(@job.project, build.git_sha)
      if configured_roles.empty?
        raise Samson::Hooks::UserError, "No kubernetes config files found at sha #{build.git_sha}"
      end

      # build config for every cluster and role we want to deploy to
      errors = []
      group_config = @job.deploy.stage.deploy_groups.map do |group|
        roles = configured_roles.map do |role|
          role_config = roles_configs.detect do |dgr|
            dgr.deploy_group_id == group.id && dgr.kubernetes_role_id == role.id
          end

          unless role_config
            errors << "No config for role #{role.name} and group #{group.name} found, add it on the stage page."
            next
          end

          {
            id: role.id,
            replicas: role_config.replicas,
            cpu: role_config.cpu,
            ram: role_config.ram
          }
        end
        {id: group.id, roles: roles}
      end

      raise Samson::Hooks::UserError, errors.join("\n") if errors.any?

      release = Kubernetes::Release.create_release(
        deploy_id: @job.deploy.id,
        deploy_groups: group_config,
        build_id: build.id,
        user: @job.user,
        project: @job.project
      )

      unless release.persisted?
        raise Samson::Hooks::UserError, "Failed to create release: #{release.errors.full_messages.inspect}"
      end

      @output.puts("Created release #{release.id}\nConfig: #{group_config.inspect}")
      release
    end

    # Create deploys
    def create_deploys(release)
      release.release_docs.each do |release_doc|
        @output.puts "Creating deploy for #{release_doc.deploy_group.name} role #{release_doc.kubernetes_role.name}"
        release_doc.deploy
      end
    end

    # Create the service or report it's status
    def ensure_service(release)
      release.release_docs.each do |release_doc|
        role = release_doc.kubernetes_role
        status = release_doc.ensure_service
        @output.puts "#{status} for role #{role.name} / service #{role.service_name.presence || "none"}"
      end
    end
  end
end
