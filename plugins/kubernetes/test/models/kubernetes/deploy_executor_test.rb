# frozen_string_literal: true
require_relative "../../test_helper"

SingleCov.covered!

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

    def worker_is_unstable
      pod_status[:containerStatuses].first[:restartCount] = 1
    end

    let(:pod_reply) do
      {
        resourceVersion: "1",
        items: [kubernetes_roles(:resque_worker), kubernetes_roles(:app_server)].map do |role|
          {
            kind: "Pod",
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
    let(:waiting_message) { "Waiting for resources" }

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
      Kubernetes::DeployExecutor.any_instance.stubs(:time_left).returns(0) # avoid loops

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
      out.must_include "resque-worker Pod: Live\n"
      out.must_include "SUCCESS"
      out.must_include waiting_message
      out.wont_include "BigDecimal" # properly serialized configs
    end

    it "watches resources until they are stable" do
      Kubernetes::DeployExecutor.any_instance.stubs(:time_left).returns(2, 1, 0)
      assert execute, out
      out.must_include "resque-worker Pod: Live\n"
      out.must_include "SUCCESS"
      out.scan(/Testing for stability/).size.must_equal 3, out
    end

    it "succeeds with external builds" do
      # image_name has to match the repo_digest
      template = Kubernetes::ReleaseDoc.new.send(:raw_template)[0]
      template[:spec][:template][:spec][:containers][0][:image] = "something.com/test:foobar"
      build.update_columns(dockerfile: nil, image_name: 'test')

      job.project.update_column :docker_image_building_disabled, true

      assert execute, out
      out.must_include "resque-worker Pod: Live\n"
      out.must_include "SUCCESS"
    end

    it "can deploy roles with 0 replicas to disable them" do
      worker_role.update_column(:replicas, 0)
      assert execute, out
      out.wont_include "resque-worker Pod: Live\n"
      out.must_include "app-server Pod: Live\n"
    end

    it "does not test for stability when not deploying any pods" do
      worker_role.update_column(:replicas, 0)
      server_role.update_column(:replicas, 0)
      assert execute, out
      out.must_include "SUCCESS"
      out.wont_include "Stable"
      out.wont_include "Deploy status after"
    end

    describe "N+1" do
      before do
        # trigger preloads
        pod_reply
        executor
      end

      it "does limited amounts of queries" do
        assert_sql_queries(16) do
          assert execute, out
        end
      end

      it "does not do nplus1 queries" do
        assert_nplus1_queries(0) do
          assert execute, out
        end
      end

      it "does not do nplus1 queries for multiple deploy-groups" do
        deploy_group = deploy_groups(:pod1)
        stage.deploy_groups_stages.create!(deploy_group: deploy_group)
        deploy_groups(:pod1).cluster_deploy_group.update_column(:namespace, 'staging')
        2.times do |i|
          copy = pod_reply[:items][i].deep_dup
          copy.dig_set [:metadata, :labels, :deploy_group_id], deploy_group.id
          pod_reply[:items] << copy
        end

        assert_nplus1_queries(1) do
          assert execute, out
        end
      end
    end

    it "show logs after succeeded deploy when requested" do
      pod_reply[:items][0][:metadata][:annotations] = {'samson/show_logs_on_deploy' => 'true'}
      assert execute, out
      out.scan("logs:").size.must_equal 1 # shows for first but not for second pod
    end

    it "can delete resources" do
      Kubernetes::DeployGroupRole.update_all(delete_resource: true)
      assert execute, out
      out.wont_include waiting_message
    end

    it "shows pods as missing when they were expected but did not show up" do
      pod_reply.fetch(:items).clear
      Kubernetes::DeployExecutor.any_instance.stubs(:time_left).returns(2, 1, 0)
      refute execute, out
      out.must_include "Pod 100 resque-worker Pod: Missing"
      out.must_match /TIMEOUT.*\n\nDebug:/ # not showing missing pod statuses after deploy
    end

    it "can use custom timeout" do
      project.kubernetes_rollout_timeout = 123
      executor.expects(:deploy_and_watch).with(anything, timeout: 123).returns(true)
      assert execute, out
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

      describe "with missing role" do
        before { worker_role.delete }

        it "fails" do
          e = assert_raises(Samson::Hooks::UserError) { execute }
          e.message.must_equal(
            "Role resque-worker for Pod 100 is not configured, but in repo at #{commit}. " \
          "Remove it from the repo or configure it via the stage page."
          )
        end

        it "passes when ignored" do
          stage.kubernetes_stage_roles.create!(kubernetes_role: worker_role.kubernetes_role, ignored: true)
          execute
          out.must_include "SUCCESS"
        end
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

        out.wont_include "deploying prerequisite" # not announcing that we have prerequisite to deploy
        out.wont_include "other roles" # not announcing that we have more to deploy
        out.wont_include "stability" # not testing for stability since it's only 1 completed pod

        out.must_include "resque-worker Pod: Live\n"
        out.must_include "SUCCESS"
      end

      it "runs prerequisites and then the deploy" do
        assert execute, out
        out.must_include "resque-worker Pod: Live\n"
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
      e.message.must_equal "Failed to create release: []" # inspected errors
    end

    it "shows status of each individual pod when there is more than 1 per deploy group" do
      worker_role.update_column(:replicas, 2)
      pod_reply[:items] << pod_reply[:items].first
      assert execute, out
      out.scan(/resque-worker Pod: Live/).count.must_equal 2
      out.must_include "SUCCESS"
    end

    it "waits when deploy is not running" do
      pod_status[:phase] = "Pending"
      pod_status.delete(:conditions)

      refute execute, out

      out.must_include "resque-worker Pod: Waiting (Pending, Unknown)\n"
    end

    it "stops when detecting a restart" do
      worker_is_unstable

      refute execute

      out.must_include "resque-worker Pod pod-resque-worker: Restarted\n"
      out.must_include "UNSTABLE"
    end

    it "stops when detecting a restart and pod goes missing" do
      worker_is_unstable
      Kubernetes::ResourceStatus.any_instance.stubs(:pod)
      Kubernetes::ResourceStatus.any_instance.stubs(:resource)

      refute execute

      out.must_include "Pod 100 resque-worker Pod: Restarted\n"
      out.must_include "UNSTABLE"
    end

    it "stops when detecting a failure" do
      pod_status[:phase] = "Failed"

      refute execute

      out.must_include "resque-worker Pod: Failed\n"
      out.must_include "UNSTABLE"
    end

    describe "percentage failure" do
      with_env KUBERNETES_ALLOW_NOT_READY_PERCENT: "50" # 1/2 allowed to fail (counting pods)

      it "fails when more than allowed amount fail" do
        worker_role.update_column(:replicas, 3) # 2 pod per role is pending = 66%
        refute execute
      end

      it "ignores when less than allowed amount fail" do
        worker_role.update_column(:replicas, 2) # 1 pod per role is pending = 50%
        assert execute
      end
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
                lastTimestamp: 1.minute.from_now.iso8601
              }
            ]
          }.to_json
        )

      refute execute

      out.must_include "resque-worker Pod: Error event\n"
      out.must_include "UNSTABLE"

      # 4 resources + once for first pod, then stops + 4 different resource events + once to debug failed pod
      assert_requested request, times: 10
    end

    it "waits when node needs to auto-scale" do
      pod_status[:phase] = "Pending"
      assert_request(
        :get,
        %r{http://foobar.server/api/v1/namespaces/staging/events.*Pod},
        to_return: {
          body: {
            items: [
              {
                type: 'Warning',
                reason: 'FailedScheduling',
                message: "0/20 nodes are available: 17 Insufficient cpu, 3 Insufficient memory.",
                lastTimestamp: 1.minute.from_now.iso8601
              }
            ]
          }.to_json
        },
        times: 2 # for first pod and again when displaying results
      )

      refute execute

      out.must_include "resque-worker Pod: Waiting for resources (Pending, Unknown)\n"
    end

    it "stops when taking too long to go live" do
      pod_status[:phase] = "Pending"
      refute execute, out
      out.must_include "TIMEOUT"
    end

    it "waits when less then expected pods are found" do
      Kubernetes::ReleaseDoc.any_instance.stubs(:desired_pod_count).returns(2)
      refute execute, out
      out.must_include "TIMEOUT"
    end

    it "waits when deploy is running but Unknown" do
      pod_status[:conditions][0][:status] = "False"
      refute execute, out
      out.must_include "resque-worker Pod: Waiting (Running, Unknown)\n"
    end

    it "fails when pod is failing to boot" do
      good = pod_reply.deep_dup
      worker_is_unstable
      stub_request(:get, %r{http://foobar.server/api/v1/namespaces/staging/pods\?}).
        to_return([{body: good.to_json}, {body: pod_reply.to_json}])

      refute executor.execute

      out.must_include "READY"
      out.must_include "UNSTABLE"
      out.must_include "resque-worker Pod pod-resque-worker: Restarted"
    end

    it "shows error when pod could not be found" do
      pod_reply[:items].clear
      refute execute, out
      out.must_include "resque-worker Pod: Missing\n"
    end

    it "fails when resource has error events" do
      assert_request(
        :get,
        %r{http://foobar.server/api/v1/namespaces/staging/events.*Deployment},
        to_return: {body: {items: [{type: 'Warning', reason: 'NO', lastTimestamp: 1.minute.from_now.iso8601}]}.to_json},
        times: 4
      )

      refute execute

      out.must_include "Deployment test-app-server events:\n  Warning NO"
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

        out.scan(/resque-worker Pod: Live/).count.must_equal 1, out
        out.must_include "(autoscaled role, only showing one pod)"
        out.must_include "SUCCESS"
      end

      it "fails when all pods fail" do
        extra_pod = pod_reply[:items].first.deep_dup
        pod_reply[:items] << extra_pod

        worker_is_unstable
        extra_pod[:status][:containerStatuses].first[:restartCount] = 1

        refute execute

        out.scan(/resque-worker Pod: Restarted/).count.must_equal 1, out
        out.scan(/resque-worker Pod pod-resque-worker: Restarted/).count.must_equal 1, out
        out.must_include "(autoscaled role, only showing one pod)"
        out.must_include "DONE"
      end

      it "still waits for a pod" do
        pod_status[:conditions][0][:status] = "False"

        refute execute, out

        out.must_include "resque-worker Pod: Waiting (Running, Unknown)"
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
        assert_request(:get, service_url, to_return: {body: old.to_json}, times: 4)
        assert_request(:put, service_url, to_return: {body: "{}"}, times: 4)

        refute execute

        out.must_include "resque-worker Pod: Restarted\n"
        out.must_include "UNSTABLE"
        out.must_include rollback_indicator
        out.must_include "DONE" # DONE is shown ... we got past the rollback
        out.wont_include "SUCCESS"
        out.wont_include "FAILED"
      end

      it "deletes when there was no previous deployed resource" do
        refute execute

        out.must_include "resque-worker Pod: Restarted\n"
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

        out.must_include "resque-worker Pod: Restarted\n"
        out.must_include "UNSTABLE"
        out.must_include "DONE" # DONE is shown ... we got past the rollback
        out.must_include "FAILED: Weird error" # rollback error cause is shown
      end

      it "does not rollback when deploy disabled it" do
        deploy.update_column(:kubernetes_rollback, false)
        Kubernetes::Resource::Deployment.any_instance.expects(:revert).never

        refute execute

        out.must_include "resque-worker Pod: Restarted\n"
        out.must_include "UNSTABLE"
        out.must_include "DONE" # DONE is shown ... we got past the rollback
      end
    end

    describe "events and logs" do
      # worker restarted -> we request the previous logs
      def expect_logs(logs = "LOG-1")
        assert_request :get, "#{log_url}&previous=true", to_return: {body: logs}
      end

      before { worker_is_unstable }

      it "displays events and logs when deploy failed" do
        expect_logs
        stub_request(:get, %r{http://foobar.server/api/v1/namespaces/staging/events}).
          to_return(
            body: {
              items: [
                {
                  reason: 'FailedScheduling',
                  type: 'Warning',
                  message: "fit failure on node (ip-1-2-3-4)\nfit failure on node (ip-2-3-4-5)",
                  count: 4,
                  lastTimestamp: 1.hour.from_now.utc.iso8601
                },
                {
                  reason: 'FailedScheduling',
                  type: 'Warning',
                  message: "fit failure on node (ip-2-3-4-5)\nfit failure on node (ip-1-2-3-4)",
                  count: 1,
                  lastTimestamp: 1.hour.from_now.utc.iso8601
                }
              ]
            }.to_json
          )

        refute execute

        # failed
        out.must_include "resque-worker Pod: Restarted\n"
        out.must_include "UNSTABLE"

        # correct debugging output
        out.scan(/pod-(\S+).*(?:events|logs)/).flatten.uniq.
          must_equal ["resque-worker"], out # logs+events only for bad pod
        out.must_match(
          /events:\s+Warning FailedScheduling: fit failure on node \(ip-1-2-3-4\)\s+fit failure on node \(ip-2-3-4-5\) x5\n\n/ # rubocop:disable Metrics/LineLength
        ) # combined repeated events
        out.must_match /logs:\s+LOG-1/
        out.must_include "events:\n  Warning FailedScheduling"
        out.must_include "Pod 100 resque-worker Service some-project events:\n  Warning FailedScheduling:"
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
                  lastTimestamp: 1.hour.from_now.utc.iso8601
                },
                {
                  reason: 'Foobar',
                  type: 'Warning',
                  count: 1,
                  lastTimestamp: 1.hour.from_now.utc.iso8601
                }
              ]
            }.to_json
          )

        refute execute

        out.must_include "Foobar:  x2"
      end

      it "displays single event" do
        stub_request(:get, %r{http://foobar.server/api/v1/namespaces/staging/events}).
          to_return(
            body: {
              items: [
                {
                  reason: 'Foobar',
                  type: 'Warning',
                  count: 1,
                  lastTimestamp: 1.hour.from_now.utc.iso8601
                }
              ]
            }.to_json
          )

        refute execute

        out.must_include "Foobar: \n"
      end

      it "ignores resource events from previous deploys" do
        expect_logs
        stub_request(:get, %r{http://foobar.server/api/v1/namespaces/staging/events.*}).
          to_return(
            body: {
              items: [
                {
                  reason: 'Foobar',
                  type: 'Warning',
                  message: 'Foobar',
                  count: 1,
                  lastTimestamp: 1.hour.ago.utc.iso8601
                }
              ]
            }.to_json
          )

        refute execute

        out.wont_include "RESOURCE events"
      end

      it "shows container names when there are multiple" do
        containers = pod_reply.dig_fetch(:items, 0, :spec, :containers)
        containers << {name: "container2"}

        assert_request :get, /log\?.*container1/, to_return: {body: "LOG-1"}
        assert_request :get, /log\?.*container2/, to_return: {body: "LOG-2"}

        refute execute, out

        out.must_include "container1"
        out.must_include "LOG-1"
        out.must_include "container2"
        out.must_include "LOG-2"
      end

      it "shows first and last part of logs when they are too long" do
        lines = 100
        expect_logs((Array.new(lines / 2) { "a" } + Array.new(lines / 2) { "b" }).join("\n"))
        refute execute, out
        out.must_include "a\n  ...\n  b"
        out.split("\n").size.must_be :<, lines
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

  describe "#time_left" do
    before do
      now = Time.now
      Time.stubs(:now).returns now
    end

    it "has time left" do
      executor.send(:time_left, Time.now.to_i - 10, 11).must_equal 1
    end

    it "has no time left" do
      executor.send(:time_left, Time.now.to_i - 10, 10).must_equal 0
    end

    it "has no time left when past due" do
      executor.send(:time_left, Time.now.to_i - 10, 9).must_equal 0
    end
  end

  describe "#print_statuses" do
    let(:status) do
      Kubernetes::ResourceStatus.new(
        resource: nil,
        role: kubernetes_roles(:app_server),
        deploy_group: deploy_groups(:pod1),
        start: nil,
        kind: "Pod"
      )
    end

    it "renders" do
      executor.send(:print_statuses, "Hey:", [status], exact: false)
      out.must_equal "Hey:\n  Pod1 app-server Pod: \n"
    end

    it "does not summarizes with moderate ammount of pods" do
      executor.send(:print_statuses, "Hey:", Array.new(3) { status.dup }, exact: false)
      out.must_equal "Hey:\n  Pod1 app-server Pod: \n  Pod1 app-server Pod: \n  Pod1 app-server Pod: \n"
    end

    it "does not summarizes when summary would be equal number of lines" do
      statuses = Array.new(20) { status.dup }
      statuses.each_slice(2).each_with_index do |group, i|
        group.each { |s| s.instance_variable_set(:@details, i) }
      end
      executor.send(:print_statuses, "Hey:", statuses, exact: false)
      out.wont_include "identical"
    end

    it "summarizes when too many identical statuses are shown" do
      executor.send(:print_statuses, "Hey:", Array.new(20) { status.dup }, exact: false)
      out.must_equal "Hey:\n  Pod1 app-server Pod: \n  ... 19 identical\n"
    end
  end

  describe "#show_failure_cause" do
    it "prints details but does not fail when something goes wrong" do
      Kubernetes::DeployExecutor.any_instance.stubs(:build_selectors).returns([])
      with_env KUBERNETES_LOG_TIMEOUT: "foo" do
        Samson::ErrorNotifier.expects(:notify).returns("Details")
        executor.send(:show_failure_cause, [])
      end
      output.string.must_equal <<~TEXT
        Error showing failure cause: Details\n
        Debug: disable 'Rollback on failure' when deploying and use 'kubectl describe pod <name>' on failed pods
      TEXT
    end
  end

  describe "#show_logs_on_deploy_if_requested" do
    it "prints erros but continues to not block the deploy" do
      Kubernetes::DeployExecutor.any_instance.stubs(:build_selectors).returns([])
      Samson::ErrorNotifier.expects(:notify).returns("Details")
      executor.send(:show_logs_on_deploy_if_requested, 123)
      output.string.must_equal "  Error showing logs: Details\n"
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

    def create_previous_succeeded_release
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
        copy.send(
          :resource_template=,
          doc.resource_template.
            map { |t| t.deep_merge(metadata: {name: t.dig(:metadata, :name).sub("-blue", "-green")}) }
        )
        copy.kubernetes_release = other
        copy
      end
      Kubernetes::Release.any_instance.stubs(:previous_succeeded_release).returns(other)
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

    it "works without a service" do
      doc = release.release_docs.first
      doc.update_column(:resource_template, doc.resource_template[0...1])

      # deployment
      assert_request(:get, "#{deployments_url}/test-app-server-blue", to_return: {status: 404}) # blue did not exist
      assert_request(:post, deployments_url, to_return: {body: "{}"}) # blue was created

      # service

      executor.expects(:wait_for_resources_to_complete).returns([true, []])
      executor.instance_variable_set(:@release, release)
      assert executor.send(:deploy_and_watch, release.release_docs, timeout: 60)

      out.must_equal "Deploying BLUE resources for Pod1 role app-server\n"
    end

    it "updates existing resources" do
      create_previous_succeeded_release

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
      executor.instance_variable_set(:@release, release)
      refute executor.send(:deploy_and_watch, release.release_docs, timeout: 60)

      out.must_equal <<~OUT
        Deploying BLUE resources for Pod1 role app-server

        Debug: disable 'Rollback on failure' when deploying and use 'kubectl describe pod <name>' on failed pods
        Deleting BLUE resources for Pod1 role app-server
        DONE
      OUT
    end
  end
end
