# frozen_string_literal: true
require_relative "../../test_helper"

SingleCov.covered! uncovered: 8

describe Kubernetes::DeployExecutor do
  assert_requests
  let(:output) { StringIO.new }
  let(:out) { output.string }
  let(:stage) { deploy.stage }
  let(:deploy) { job.deploy }
  let(:job) { jobs(:succeeded_test) }
  let(:project) { job.project }
  let(:build) { builds(:docker_build) }
  let(:deploy_group) { stage.deploy_groups.first }
  let(:executor) { Kubernetes::DeployExecutor.new(job, output) }
  let(:log_url) { "http://foobar.server/api/v1/namespaces/staging/pods/pod-resque-worker/log?container=container1" }
  let(:commit) { '1a6f551a2ffa6d88e15eef5461384da0bfb1c194' }
  let(:origin) { "http://foobar.server" }
  let(:maxitest_timeout) { 10 }

  before do
    stage.update_column :kubernetes, true
    deploy.update_column :kubernetes, true
  end

  describe "#pid" do
    it "returns a fake pid" do
      Kubernetes::DeployExecutor.any_instance.stubs(:build_selectors).returns([])
      executor.pid.must_include "Kubernetes"
    end
  end

  describe "#pgid" do
    it "returns a fake pid" do
      Kubernetes::DeployExecutor.any_instance.stubs(:build_selectors).returns([])
      executor.pgid.must_include "Kubernetes"
    end
  end

  describe "#execute" do
    def execute
      stub_request(:get, %r{http://foobar.server/api/v1/namespaces/staging/pods\?}).
        to_return(body: pod_reply.to_json) # checks pod status to see if it's good
      executor.execute
    end

    def cancel_after_first_iteration
      executor.stubs(:sleep).with { raise JobQueue::Cancel } # cannot use .expect, the raise does not count invocation
    end

    # make the first sleep take a long time so we trigger our timeout condition
    def timeout_after_first_iteration
      start = Time.now
      Time.stubs(:now).returns(start)
      executor.expects(:sleep).with { Time.stubs(:now).returns(start + 1.hour); true }
    end

    def worker_is_unstable
      pod_status[:containerStatuses].first[:restartCount] = 1
    end

    let(:pod_reply) do
      {
        resourceVersion: "1",
        items: [kubernetes_roles(:resque_worker), kubernetes_roles(:app_server)].map do |role|
          {
            status: {
              phase: "Running",
              conditions: [{type: "Ready", status: "True"}],
              containerStatuses: [{restartCount: 0, state: {}}]
            },
            metadata: {
              name: "pod-#{role.name}",
              namespace: 'staging',
              labels: {deploy_group_id: deploy_group.id.to_s, role_id: role.id.to_s}
            },
            spec: {
              containers: [
                {name: 'container1'}
              ]
            },
          }
        end
      }
    end
    let(:pod_status) { pod_reply[:items].first[:status] }
    let(:worker_role) { kubernetes_deploy_group_roles(:test_pod100_resque_worker) }
    let(:server_role) { kubernetes_deploy_group_roles(:test_pod100_app_server) }
    let(:deployments_url) { "http://foobar.server/apis/extensions/v1beta1/namespaces/staging/deployments" }
    let(:jobs_url) { "http://foobar.server/apis/batch/v1/namespaces/staging/deployments" }
    let(:service_url) { "http://foobar.server/api/v1/namespaces/staging/services/some-project" }

    before do
      Kubernetes::DeployGroupRole.update_all(replicas: 1)
      job.update_column(:commit, build.git_sha) # this is normally done by JobExecution
      Kubernetes::Role.stubs(:configured_for_project).returns(project.kubernetes_roles)
      kubernetes_fake_raw_template
      Kubernetes::Cluster.any_instance.stubs(connection_valid?: true, namespaces: ['staging'])
      deploy_group.create_cluster_deploy_group!(
        cluster: kubernetes_clusters(:test_cluster),
        namespace: 'staging',
        deploy_group: deploy_group
      )

      stub_request(:get, "#{deployments_url}/test-app-server").to_return(status: 404) # previous deploys ? -> none!
      stub_request(:get, "#{deployments_url}/test-resque-worker").to_return(status: 404) # previous deploys ? -> none!
      stub_request(:post, deployments_url).to_return(body: "{}") # creates deployment
      stub_request(:put, "#{deployments_url}/test-resque-worker").to_return(body: '{}') # during delete for rollback

      Kubernetes::DeployExecutor.any_instance.stubs(:sleep) # not using .executor to keep it uninitialized
      Kubernetes::DeployExecutor.any_instance.stubs(:stable?).returns(true) # otherwise takes a real minute

      stub_request(:get, %r{http://foobar.server/api/v1/namespaces/staging/events}).to_return(body: {items: []}.to_json)
      stub_request(:get, /#{Regexp.escape(log_url)}/)

      GitRepository.any_instance.stubs(:file_content).with('Dockerfile', commit).returns "FROM all"
      GitRepository.any_instance.stubs(:file_content).with('kubernetes/resque_worker.yml', commit, anything).
        returns(read_kubernetes_sample_file('kubernetes_deployment.yml'))
      GitRepository.any_instance.stubs(:file_content).with('kubernetes/app_server.yml', commit, anything).
        returns(read_kubernetes_sample_file('kubernetes_deployment.yml').gsub(/some-role/, 'other-role'))

      Kubernetes::TemplateFiller.any_instance.stubs(:set_image_pull_secrets)

      stub_request(:get, service_url).to_return(status: 404) # previous service ? -> none!
      stub_request(:post, File.dirname(service_url)).to_return(body: "{}")
      stub_request(:delete, service_url).to_return(body: "{}")

      Samson::Secrets::VaultClientManager.any_instance.stubs(:client).
        returns(stub(options: {address: 'https://test.hvault.server', ssl_verify: false}, versioned_kv: false))
    end

    it "succeeds" do
      assert execute, out
      out.must_include "resque-worker: Live\n"
      out.must_include "SUCCESS"
      out.wont_include "BigDecimal" # properly serialized configs
    end

    it "succeeds with external builds" do
      # image_name has to match the repo_digest
      template = Kubernetes::ReleaseDoc.new.send(:raw_template)[0]
      template[:spec][:template][:spec][:containers][0][:image] = "something.com/test:foobar"
      build.update_columns(dockerfile: nil, image_name: 'test')

      job.project.update_column :docker_image_building_disabled, true

      assert execute, out
      out.must_include "resque-worker: Live\n"
      out.must_include "SUCCESS"
    end

    it "can deploy roles with 0 replicas to disable them" do
      worker_role.update_column(:replicas, 0)
      assert execute, out
      out.wont_include "resque-worker: Live\n"
      out.must_include "app-server: Live\n"
    end

    it "does not test for stability when not deploying any pods" do
      worker_role.update_column(:replicas, 0)
      server_role.update_column(:replicas, 0)
      assert execute, out
      out.must_include "SUCCESS"
      out.wont_include "Stable"
      out.wont_include "Deploy status after"
    end

    it "does limited amounts of queries" do
      assert_sql_queries(27) do
        assert execute, out
      end
    end

    it "show logs after successful deploy when requested" do
      pod_reply[:items][0][:metadata][:annotations] = {'samson/show_logs_on_deploy' => 'true'}
      assert execute, out
      out.scan("LOGS:").size.must_equal 1 # shows for first but not for second pod
    end

    describe "invalid configs" do
      before { build.delete } # build needs to be created -> assertion fails
      around { |test| refute_difference('Build.count') { refute_difference('Release.count', &test) } }

      it "fails before building when a role are invalid" do
        Kubernetes::DeployExecutor.any_instance.stubs(:build_selectors).returns([])
        Kubernetes::ReleaseDoc.any_instance.unstub(:raw_template)
        GitRepository.any_instance.expects(:file_content).with { |file| file =~ /^kubernetes\// }.returns("oops: bad")

        e = assert_raises Samson::Hooks::UserError do
          refute execute
        end
        e.message.must_include "Error parsing kubernetes/" # order is random so we check prefix
      end

      it "fails before building when roles as a group are invalid" do
        # same role as worker
        GitRepository.any_instance.stubs(:file_content).with('kubernetes/app_server.yml', commit, anything).
          returns(read_kubernetes_sample_file('kubernetes_deployment.yml'))

        e = assert_raises Samson::Hooks::UserError do
          refute execute
        end
        e.message.must_equal "metadata.labels.role must be set and unique"
      end

      it "fails before building when secrets are not configured in the backend" do
        stub_const Kubernetes::TemplateFiller, :SECRET_PULLER_IMAGE, 'foo' do
          # overriding the stubbed value
          template = Kubernetes::ReleaseDoc.new.send(:raw_template)[0]
          template[:spec][:template][:metadata][:annotations] = {"secret/foo": "bar"}

          e = assert_raises Samson::Hooks::UserError do
            refute execute
          end
          e.message.must_include "Failed to resolve secret keys:\n\tbar"
        end
      end

      it "fails before building when env is not configured" do
        # overriding the stubbed value
        template = Kubernetes::ReleaseDoc.new.send(:raw_template)[0]
        template[:spec][:template][:metadata][:annotations] = {"samson/required_env": "FOO BAR"}

        e = assert_raises Samson::Hooks::UserError do
          refute execute
        end
        e.message.must_include "Missing env variables [\"FOO\", \"BAR\"]"
      end

      it "fails before building when role config is missing" do
        GitRepository.any_instance.stubs(:file_content).with('kubernetes/resque_worker.yml', commit, anything).
          returns(nil)

        e = assert_raises Samson::Hooks::UserError do
          refute execute
        end
        e.message.must_include "Error parsing kubernetes/resque_worker.yml"
      end
    end

    describe "role settings" do
      it "uses configured role settings" do
        assert execute, out
        doc = Kubernetes::Release.last.release_docs.max_by(&:kubernetes_role)
        config = server_role
        doc.replica_target.must_equal config.replicas
        doc.limits_cpu.must_equal config.limits_cpu
        doc.limits_memory.must_equal config.limits_memory
      end

      it "fails when role config is missing" do
        worker_role.delete
        e = assert_raises(Samson::Hooks::UserError) { execute }
        e.message.must_equal(
          "Role resque-worker for Pod 100 is not configured, but in repo at #{commit}. " \
          "Remove it from the repo or configure it via the stage page."
        )
      end

      it "fails when no role is setup in the project" do
        Kubernetes::Role.stubs(:configured_for_project).returns([worker_role])
        e = assert_raises(Samson::Hooks::UserError) { execute }
        e.message.must_equal(
          "Could not find config files for Pod 100 kubernetes/app_server.yml, kubernetes/resque_worker.yml" \
          " at #{commit}"
        )
      end
    end

    describe "running a job before the deploy" do
      before do
        # we need multiple different templates here
        # make the worker a job and keep the app server
        Kubernetes::ReleaseDoc.any_instance.unstub(:raw_template)
        GitRepository.any_instance.stubs(:file_content).with('kubernetes/resque_worker.yml', commit).returns({
          'kind' => 'Job',
          'apiVersion' => 'batch/v1',
          'spec' => {
            'template' => {
              'metadata' => {'labels' => {'project' => 'foobar', 'role' => 'migrate'}},
              'spec' => {
                'containers' => [{'name' => 'job', 'image' => 'docker-registry.zende.sk/truth_service:latest'}],
                'restartPolicy' => 'Never'
              }
            }
          },
          'metadata' => {
            'name' => 'test',
            'labels' => {'project' => 'foobar', 'role' => 'migrate'},
            'annotations' => {'samson/prerequisite' => 'true'}
          }
        }.to_yaml)
        GitRepository.any_instance.stubs(:file_content).with('kubernetes/app_server.yml', commit).
          returns(read_kubernetes_sample_file('kubernetes_deployment.yml'))

        # check if the job already exists ... it does not
        stub_request(:get, "http://foobar.server/apis/batch/v1/namespaces/staging/jobs/test-resque-worker").
          to_return(status: 404)

        # create job
        stub_request(:post, "http://foobar.server/apis/batch/v1/namespaces/staging/jobs").
          to_return(body: '{}')

        # mark the job as Succeeded
        pod_reply[:items][0][:status][:phase] = 'Succeeded'
      end

      it "runs only jobs" do
        kubernetes_roles(:app_server).destroy
        assert execute, out
        out.must_include "resque-worker: Live\n"
        out.must_include "SUCCESS"
        out.wont_include "stability"
        out.wont_include "deploying jobs" # not announcing that we deploy jobs since there is nothing else
        out.wont_include "other roles" # not announcing that we have more to deploy
      end

      it "runs prerequisites and then the deploy" do
        assert execute, out
        out.must_include "resque-worker: Live\n"
        out.must_include "SUCCESS"
        out.must_include "stability" # testing deploy for stability
        out.must_include "deploying prerequisite" # announcing that we deploy prerequisites first
        out.must_include "other roles" # announcing that we have more to deploy
      end

      it "fails when jobs fail" do
        executor.expects(:deploy_and_watch).returns false # jobs failed, they are the first execution
        refute execute
        out.wont_include "SUCCESS"
        out.wont_include "stability"
        out.wont_include "other roles" # not announcing that we have more to deploy
      end
    end

    it "fails when release has errors" do
      Kubernetes::Release.any_instance.expects(:persisted?).at_least_once.returns(false)
      e = assert_raises(Samson::Hooks::UserError) { execute }
      e.message.must_equal "Failed to create release: []" # inspected errros
    end

    it "shows status of each individual pod when there is more than 1 per deploy group" do
      worker_role.update_column(:replicas, 2)
      pod_reply[:items] << pod_reply[:items].first
      assert execute, out
      out.scan(/resque-worker: Live/).count.must_equal 2
      out.must_include "SUCCESS"
    end

    it "waits when deploy is not running" do
      pod_status[:phase] = "Pending"
      pod_status.delete(:conditions)

      cancel_after_first_iteration
      assert_raises(JobQueue::Cancel) { execute }

      out.must_include "resque-worker: Waiting (Pending, Unknown)\n"
    end

    it "stops when detecting a restart" do
      worker_is_unstable

      refute execute

      out.must_include "resque-worker: Restarted\n"
      out.must_include "UNSTABLE"
    end

    it "stops when detecting a restart and pod goes missing" do
      worker_is_unstable
      Kubernetes::DeployExecutor::ReleaseStatus.any_instance.stubs(:pod)

      refute execute

      out.must_include "resque-worker: Restarted\n"
      out.must_include "UNSTABLE"
    end

    it "stops when detecting a failure" do
      pod_status[:phase] = "Failed"

      refute execute

      out.must_include "resque-worker: Failed\n"
      out.must_include "UNSTABLE"
    end

    it "stops when detecting a failure via events" do
      pod_status[:phase] = "Pending"
      request = stub_request(:get, %r{http://foobar.server/api/v1/namespaces/staging/events}).
        to_return(
          body: {
            items: [
              {
                type: 'Warning',
                reason: 'Unhealthy',
                message: "kubelet, ip-12-34-56-78 Liveness probe failed: Get http://12.34.56.78/ping",
                metadata: {creationTimestamp: "2017-03-31T22:56:20Z"}
              }
            ]
          }.to_json
        )

      refute execute

      out.must_include "resque-worker: Error event\n"
      out.must_include "UNSTABLE"

      assert_requested request, times: 5 # fetches pod events once and once for 4 different resources
    end

    it "waits when node needs to auto-scale" do
      pod_status[:phase] = "Pending"
      request = stub_request(:get, %r{http://foobar.server/api/v1/namespaces/staging/events}).
        to_return(
          body: {
            items: [
              {
                type: 'Warning',
                reason: 'FailedScheduling',
                message: "0/20 nodes are available: 17 Insufficient cpu, 3 Insufficient memory.",
                metadata: {creationTimestamp: "2017-03-31T22:56:20Z"}
              }
            ]
          }.to_json
        )

      cancel_after_first_iteration
      assert_raises(JobQueue::Cancel) { execute }

      assert_requested request
      out.must_include "resque-worker: Waiting for resources (Pending, Unknown)\n"
    end

    it "stops when taking too long to go live" do
      pod_status[:phase] = "Pending"
      timeout_after_first_iteration
      refute execute
      out.must_include "TIMEOUT"
    end

    it "waits when less then exected pods are found" do
      Kubernetes::ReleaseDoc.any_instance.stubs(:desired_pod_count).returns(2)
      timeout_after_first_iteration
      refute execute
      out.must_include "TIMEOUT"
    end

    it "waits when deploy is running but Unknown" do
      pod_status[:conditions][0][:status] = "False"

      cancel_after_first_iteration
      assert_raises(JobQueue::Cancel) { execute }

      out.must_include "resque-worker: Waiting (Running, Unknown)\n"
    end

    it "fails when pod is failing to boot" do
      good = pod_reply.deep_dup
      worker_is_unstable
      stub_request(:get, %r{http://foobar.server/api/v1/namespaces/staging/pods\?}).
        to_return([{body: good.to_json}, {body: pod_reply.to_json}])

      refute executor.execute

      out.must_include "READY"
      out.must_include "UNSTABLE"
      out.must_include "resque-worker: Restarted"
    end

    # not sure if this will ever happen ...
    it "shows error when pod could not be found" do
      pod_reply[:items].clear

      cancel_after_first_iteration
      assert_raises(JobQueue::Cancel) { execute }

      out.must_include "resque-worker: Missing\n"
    end

    describe "an autoscaled role" do
      before do
        worker_role.kubernetes_role.update_column(:autoscaled, true)
        worker_role.update_column(:replicas, 2)
      end

      it "only requires one pod to go live when a role is autoscaled" do
        pod_reply[:items] << pod_reply[:items].first.deep_dup

        worker_is_unstable

        assert execute, out

        out.scan(/resque-worker: Live/).count.must_equal 1
        out.must_include "(autoscaled role, only showing one pod)"
        out.must_include "SUCCESS"
      end

      it "fails when all pods fail" do
        extra_pod = pod_reply[:items].first.deep_dup
        pod_reply[:items] << extra_pod

        worker_is_unstable
        extra_pod[:status][:containerStatuses].first[:restartCount] = 1

        refute execute

        out.scan(/resque-worker: Restarted/).count.must_equal 2
        out.must_include "(autoscaled role, only showing one pod)"
        out.must_include "DONE"
      end

      it "still waits for a pod" do
        pod_status[:conditions][0][:status] = "False"

        cancel_after_first_iteration
        assert_raises(JobQueue::Cancel) { execute }

        out.must_include "resque-worker: Waiting (Running, Unknown)"
      end
    end

    describe "when rollback is needed" do
      let(:rollback_indicator) { "Rolling back" }

      before { worker_is_unstable }

      it "rolls back when previous resource existed" do
        old = {
          kind: 'Service',
          apiVersion: 'v1',
          metadata: {uid: '123', name: 'some-project', namespace: 'staging', resourceVersion: 'X'},
          spec: {clusterIP: "Y"}
        }
        assert_request(:get, service_url, to_return: {body: old.to_json}, times: 6)
        assert_request(:put, service_url, to_return: {body: "{}"}, times: 4)

        refute execute

        out.must_include "resque-worker: Restarted\n"
        out.must_include "UNSTABLE"
        out.must_include rollback_indicator
        out.must_include "DONE" # DONE is shown ... we got past the rollback
        out.wont_include "SUCCESS"
        out.wont_include "FAILED"
      end

      it "deletes when there was no previous deployed resource" do
        refute execute

        out.must_include "resque-worker: Restarted\n"
        out.must_include "UNSTABLE"
        out.must_include "Deleting"
        out.wont_include rollback_indicator
        out.must_include "DONE" # DONE is shown ... we got past the rollback
        out.wont_include "SUCCESS"
        out.wont_include "FAILED"
      end

      it "does not crash when rollback fails" do
        Kubernetes::Resource::Deployment.any_instance.stubs(:revert).raises("Weird error")

        refute execute

        out.must_include "resque-worker: Restarted\n"
        out.must_include "UNSTABLE"
        out.must_include "DONE" # DONE is shown ... we got past the rollback
        out.must_include "FAILED: Weird error" # rollback error cause is shown
      end

      it "does not rollback when deploy disabled it" do
        deploy.update_column(:kubernetes_rollback, false)
        Kubernetes::Resource::Deployment.any_instance.expects(:revert).never

        refute execute

        out.must_include "resque-worker: Restarted\n"
        out.must_include "UNSTABLE"
        out.must_include "DONE" # DONE is shown ... we got past the rollback
      end
    end

    describe "events and logs" do
      before do
        # worker restarted -> we request the previous logs
        stub_request(:get, "#{log_url}&previous=true").to_return(body: "LOG-1")

        worker_is_unstable
      end

      it "displays events and logs when deploy failed" do
        stub_request(:get, %r{http://foobar.server/api/v1/namespaces/staging/events}).
          to_return(
            body: {
              items: [
                {
                  reason: 'FailedScheduling',
                  type: 'Warning',
                  message: "fit failure on node (ip-1-2-3-4)\nfit failure on node (ip-2-3-4-5)",
                  count: 4,
                  metadata: {creationTimestamp: "2017-03-31T22:56:20Z"}
                },
                {
                  reason: 'FailedScheduling',
                  type: 'Warning',
                  message: "fit failure on node (ip-2-3-4-5)\nfit failure on node (ip-1-2-3-4)",
                  count: 1,
                  metadata: {creationTimestamp: "2017-03-31T22:56:20Z"}
                }
              ]
            }.to_json
          )

        refute execute

        # failed
        out.must_include "resque-worker: Restarted\n"
        out.must_include "UNSTABLE"

        # correct debugging output
        out.scan(/Pod 100 pod pod-(\S+)/).flatten.uniq.must_equal ["resque-worker:"] # logs and events only for bad pod
        out.must_match(
          /EVENTS:\s+Warning FailedScheduling: fit failure on node \(ip-1-2-3-4\)\s+fit failure on node \(ip-2-3-4-5\) x5\n\n/ # rubocop:disable Metrics/LineLength
        ) # no repeated events
        out.must_match /LOGS:\s+LOG-1/
        out.must_include "RESOURCE EVENTS staging.some-project:\n  Warning FailedScheduling:"
      end

      it "displays events without message" do
        stub_request(:get, %r{http://foobar.server/api/v1/namespaces/staging/events}).
          to_return(
            body: {
              items: [
                {
                  reason: 'Foobar',
                  type: 'Warning',
                  count: 1,
                  metadata: {creationTimestamp: "2017-03-31T22:56:20Z"}
                },
                {
                  reason: 'Foobar',
                  type: 'Warning',
                  count: 1,
                  metadata: {creationTimestamp: "2017-03-31T22:56:20Z"}
                }
              ]
            }.to_json
          )

        refute execute

        out.must_include "Foobar:  x2"
      end
    end
  end

  describe "#fetch_pods" do
    before do
      Kubernetes::DeployExecutor.any_instance.stubs(:build_selectors).returns([])
    end
    it "retries on failure" do
      Kubeclient::Client.any_instance.expects(:get_pods).times(4).raises(Kubeclient::HttpError.new(1, 2, 3))
      executor.instance_variable_set(:@release, kubernetes_releases(:test_release))
      assert_raises(Kubeclient::HttpError) { executor.send(:fetch_pods) }
    end

    it "retries on ssl failure" do
      Kubeclient::Client.any_instance.expects(:get_pods).times(4).raises(OpenSSL::SSL::SSLError.new)
      executor.instance_variable_set(:@release, kubernetes_releases(:test_release))
      assert_raises(OpenSSL::SSL::SSLError) { executor.send(:fetch_pods) }
    end
  end

  describe "#stable?" do
    it "is stable when enough time has passed" do
      assert executor.send(:stable?, 0)
    end

    it "is unstable when recently deployed" do
      refute executor.send(:stable?, 40)
    end
  end

  describe "#show_failure_cause" do
    it "prints details but does not fail when something goes wrong" do
      Kubernetes::DeployExecutor.any_instance.stubs(:build_selectors).returns([])
      with_env KUBERNETES_LOG_TIMEOUT: "foo" do
        ErrorNotifier.expects(:notify).returns("Details")
        executor.send(:show_failure_cause, [], [])
      end
      output.string.must_equal "Error showing failure cause: Details\n"
    end
  end

  describe "#show_logs_on_deploy_if_requested" do
    it "prints erros but continues to not block the deploy" do
      Kubernetes::DeployExecutor.any_instance.stubs(:build_selectors).returns([])
      ErrorNotifier.expects(:notify).returns("Details")
      executor.send(:show_logs_on_deploy_if_requested, 123)
      output.string.must_equal "Error showing logs: Details\n"
    end
  end

  describe "#allowed_not_ready" do
    let(:log_string) { "Ignored" }

    it "allows none when percent is not set" do
      executor.send(:allowed_not_ready, 10).must_equal 0
    end

    it "allows given percentage" do
      with_env KUBERNETES_ALLOW_NOT_READY_PERCENT: "30" do
        executor.send(:allowed_not_ready, 10).must_equal 3
      end
    end

    it "does not blow up on 0" do
      with_env KUBERNETES_ALLOW_NOT_READY_PERCENT: "50" do
        executor.send(:allowed_not_ready, 0).must_equal 0
      end
    end
  end

  describe "blue green" do
    def add_service_to_release_doc
      kubernetes_fake_raw_template
      Kubernetes::TemplateFiller.any_instance.stubs(:set_image_pull_secrets)
      doc = release.release_docs.first
      doc.kubernetes_release.builds = [build]
      doc.send(:store_resource_template)
      doc.save!(validate: false)
    end

    def create_previous_successful_release
      other = Kubernetes::Release.new(
        user: release.user,
        project: release.project,
        git_sha: release.git_sha,
        git_ref: "master",
        deploy: release.deploy,
        blue_green_color: "green"
      )
      other.release_docs = release.release_docs.map do |doc|
        copy = Kubernetes::ReleaseDoc.new(doc.attributes.except('resource_template'))
        copy.send(:resource_template=, doc.resource_template.map do |t|
          t.deep_merge(metadata: {name: t.dig(:metadata, :name).sub("-blue", "-green")})
        end)
        copy.kubernetes_release = other
        copy
      end
      Kubernetes::Release.any_instance.stubs(:previous_successful_release).returns(other)
    end

    let(:deployments_url) { "#{origin}/apis/extensions/v1beta1/namespaces/pod1/deployments" }
    let(:services_url) { "#{origin}/api/v1/namespaces/pod1/services" }
    let(:release) { kubernetes_releases(:test_release) }

    before do
      kubernetes_roles(:app_server).update_columns blue_green: true
      release.update_columns blue_green_color: "blue"
      add_service_to_release_doc
      Kubernetes::DeployExecutor.any_instance.stubs(:build_selectors).returns([])
    end

    it "deploys new resources" do
      # deployment
      assert_request(:get, "#{deployments_url}/test-app-server-blue", to_return: {status: 404}) # blue did not exist
      assert_request(:post, deployments_url, to_return: {body: "{}"}) # blue was created

      # service
      assert_request(:get, "#{services_url}/some-project", to_return: {status: 404}) # did not exist
      assert_request(:post, services_url, to_return: {body: "{}"}) # blue was created

      executor.expects(:wait_for_resources_to_complete).returns([true, []])
      executor.instance_variable_set(:@release, release)
      assert executor.send(:deploy_and_watch, release.release_docs, timeout: 60)

      out.must_equal <<~OUT
        Deploying BLUE resources for Pod1 role app-server
        Switching service for Pod1 role app-server to BLUE
      OUT
    end

    it "updates existing resources" do
      create_previous_successful_release

      # deployment
      assert_request(:get, "#{deployments_url}/test-app-server-blue", to_return: {status: 404}) # blue did not exist
      assert_request(:post, deployments_url, to_return: {body: "{}"}) # blue was created

      # service
      assert_request(:get, "#{services_url}/some-project", to_return: {body: "{}"}) # existed
      assert_request(:put, "#{services_url}/some-project", to_return: {body: "{}"}) # update to point to blue

      # delete old deployment
      assert_request(
        :get, "#{deployments_url}/test-app-server-green",
        to_return: [{body: "{}"}, {body: "{}"}, {status: 404}] # green did exist and gets deleted
      )
      assert_request(:put, "#{deployments_url}/test-app-server-green", to_return: {body: "{}"}) # set green to 0
      assert_request(:delete, "#{deployments_url}/test-app-server-green", to_return: {body: "{}"}) # delete green

      executor.expects(:wait_for_resources_to_complete).returns([true, []])
      executor.instance_variable_set(:@release, release)
      assert executor.send(:deploy_and_watch, release.release_docs, timeout: 60)

      out.must_equal <<~OUT
        Deploying BLUE resources for Pod1 role app-server
        Switching service for Pod1 role app-server to BLUE
        Deleting GREEN resources for Pod1 role app-server
      OUT
    end

    it "reverts new resources when they fail" do
      # deployment
      assert_request(
        :get, "#{deployments_url}/test-app-server-blue", to_return:
        [
          {status: 404}, {body: "{}"}, {body: "{}"}, {status: 404} # blue did not exist + 3 replies for deletion
        ]
      )
      assert_request(:post, deployments_url, to_return: {body: "{}"}) # blue was created
      assert_request(:put, "#{deployments_url}/test-app-server-blue", to_return: {body: "{}"}) # set blue to 0
      assert_request(:delete, "#{deployments_url}/test-app-server-blue", to_return: {body: "{}"}) # delete blue

      executor.expects(:wait_for_resources_to_complete).returns([false, []])
      executor.expects(:print_resource_events)
      executor.instance_variable_set(:@release, release)
      refute executor.send(:deploy_and_watch, release.release_docs, timeout: 60)

      out.must_equal <<~OUT
        Deploying BLUE resources for Pod1 role app-server
        Deleting BLUE resources for Pod1 role app-server
        DONE
      OUT
    end
  end
end
