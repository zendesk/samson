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
  let(:cluster) { create_kubernetes_cluster }
  let(:deploy_group) { stage.deploy_groups.first }
  let(:executor) { Kubernetes::DeployExecutor.new(job, output) }
  let(:log_url) { "http://foobar.server/api/v1/namespaces/staging/pods/pod-resque-worker/log?container=container1" }
  let(:commit) { '1a6f551a2ffa6d88e15eef5461384da0bfb1c194' }
  let(:origin) { "http://foobar.server" }
  let(:maxitest_timeout) { 10 }

  before do
    stage.update_column :kubernetes, true
    deploy.update_column :kubernetes, true
    deploy_group.update kubernetes_cluster: cluster
  end

  describe "#preview_release_docs" do
    let(:worker_role) { Kubernetes::Role.find_by(name: "resque-worker") }

    before do
      job.update_column(:commit, build.git_sha) # this is normally done by JobExecution

      stage.update(deploy_groups: [deploy_group])
      stage.kubernetes_stage_roles.create(kubernetes_role: worker_role, ignored: true)

      GitRepository.any_instance.stubs(:file_content).
        with(any_of('kubernetes/app_server.yml', 'kubernetes/resque_worker.yml'), commit, anything).
        returns(read_kubernetes_sample_file('kubernetes_deployment.yml'))
    end

    it "returns built release docs" do
      release_docs = assert_no_difference [
        'Deploy.count',
        'Job.count',
        'Kubernetes::Release.count',
        'Kubernetes::ReleaseDoc.count'
      ] do
        executor.preview_release_docs
      end

      release_docs.size.must_equal 1
      release_docs.first.persisted?.must_equal false
    end

    it "skips looking up build when resolve_build is false" do
      Samson::BuildFinder.any_instance.expects(:ensure_succeeded_builds).never

      release_docs = assert_no_difference [
        'Deploy.count',
        'Job.count',
        'Kubernetes::Release.count',
        'Kubernetes::ReleaseDoc.count'
      ] do
        executor.preview_release_docs(resolve_build: false)
      end

      release_docs.size.must_equal 1
      release_docs.first.persisted?.must_equal false
    end

    it "raises when release is invalid" do
      Kubernetes::Release.any_instance.expects(:valid?).at_least_once.returns(false)

      assert_raises Samson::Hooks::UserError do
        executor.preview_release_docs
      end
    end
  end

  describe "#execute" do
    def execute
      stub_request(:get, %r{http://foobar.server/api/v1/namespaces/staging/pods\?}).
        to_return(*pod_responses) # checks pod status to see if it's good
      stub_request(:get, %r{http://foobar.server/apis/apps/v1/namespaces/staging/replicasets\?}).
        to_return(body: replica_sets_reply.to_json)
      executor.execute
    end

    def worker_is_unstable
      pod_status[:containerStatuses].first[:restartCount] = 1
    end

    let(:pod_responses) { [{body: pod_reply.to_json}] }
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
    let(:replica_sets_reply) { {items: []} }
    let(:pod_status) { pod_reply.dig(:items, 0, :status) }
    let(:worker_role) { kubernetes_deploy_group_roles(:test_pod100_resque_worker) }
    let(:server_role) { kubernetes_deploy_group_roles(:test_pod100_app_server) }
    let(:deployments_url) { "http://foobar.server/apis/apps/v1/namespaces/staging/deployments" }
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
      deploy.builds.must_equal [build]
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
      pod_reply[:items].shift # remove the worker pod
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
        assert_sql_queries(17) do
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

        assert_nplus1_queries 0 do
          assert execute, out
        end
      end
    end

    it "show logs after succeeded deploy when requested via annotation" do
      pod_reply[:items][0][:metadata][:annotations] = {'samson/show_logs_on_deploy' => 'true'}
      assert execute, out
      out.scan("logs:").size.must_equal 1 # shows for first but not for second pod
    end

    it "show logs after succeeded deploy when requested via stage" do
      assert_request(:get, /pod-app-server\/log/) do
        stage.kubernetes_sample_logs_on_success = true
        assert execute, out
        out.scan("logs:").size.must_equal 2 # shows for 1 per role
      end
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

    it "can use dynamic folders" do
      GitRepository.any_instance.expects(:file_content).with('kubernetes/pod100/resque_worker.yml', commit, anything).
        returns(read_kubernetes_sample_file('kubernetes_deployment.yml'))
      GitRepository.any_instance.expects(:file_content).with('kubernetes/pod100/app_server.yml', commit, anything).
        returns(read_kubernetes_sample_file('kubernetes_deployment.yml').gsub(/some-role/, 'other-role'))
      kubernetes_roles(:app_server).update_column(:config_file, 'kubernetes/$deploy_group/app_server.yml')
      kubernetes_roles(:resque_worker).update_column(:config_file, 'kubernetes/$deploy_group/resque_worker.yml')
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
        e.message.must_include "Error found when validating kubernetes/" # order is random so we check prefix
      end

      it "fails before building when roles as a group are invalid" do
        # same role as worker
        GitRepository.any_instance.stubs(:file_content).with('kubernetes/app_server.yml', commit, anything).
          returns(read_kubernetes_sample_file('kubernetes_deployment.yml'))

        e = assert_raises Samson::Hooks::UserError do
          refute execute
        end
        e.message.must_equal "metadata.labels.role must be set and different in each role"
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

      it "fails before building when deploy groups are empty" do
        stage.update(deploy_groups: [])

        e = assert_raises Samson::Hooks::UserError do
          refute execute
        end
        e.message.must_equal "No deploy groups are configured for this stage."
      end

      it "fails before building when role config is missing" do
        GitRepository.any_instance.stubs(:file_content).with('kubernetes/resque_worker.yml', commit, anything).
          returns(nil)

        e = assert_raises Samson::Hooks::UserError do
          refute execute
        end
        e.message.must_equal "does not contain config file 'kubernetes/resque_worker.yml'"
      end
    end

    describe "role settings" do
      it "uses configured role settings" do
        assert execute, out
        doc = Kubernetes::Release.last.release_docs.max_by(&:kubernetes_role)
        config = server_role
        doc.replica_target.must_equal config.replicas
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
        GitRepository.any_instance.unstub(:file_content)
        GitRepository.any_instance.stubs(:file_content).with('kubernetes/resque_worker.yml', commit, anything).returns({
          'kind' => 'Job',
          'apiVersion' => 'batch/v1',
          'spec' => {
            'template' => {
              'metadata' => {'labels' => {'project' => 'some-project', 'role' => 'migrate'}},
              'spec' => {
                'containers' => [{'name' => 'job', 'image' => 'docker-registry.zende.sk/truth_service:latest'}],
                'restartPolicy' => 'Never'
              }
            }
          },
          'metadata' => {
            'name' => 'test',
            'labels' => {'project' => 'some-project', 'role' => 'migrate'},
            'annotations' => {'samson/prerequisite' => 'true'}
          }
        }.to_yaml)
        GitRepository.any_instance.stubs(:file_content).with('kubernetes/app_server.yml', commit, anything).
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
      Kubernetes::Release.any_instance.expects(:save).at_least_once.returns(false)
      e = assert_raises(Samson::Hooks::UserError) { execute }
      e.message.must_equal "Failed to store manifests: []" # inspected errors
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

      out.must_include "resque-worker Pod pod-resque-worker: Restarted"
      out.must_include "UNSTABLE"
    end

    it "stops when detecting a restart and pod goes missing" do
      worker_is_unstable
      Kubernetes::ResourceStatus.any_instance.stubs(:pod)
      Kubernetes::ResourceStatus.any_instance.stubs(:resource)

      refute execute

      out.must_include "Pod 100 resque-worker Pod: Restarted"
      out.must_include "UNSTABLE"
    end

    it "stops when detecting a failure" do
      pod_reply.dig_set([:items, 0, :spec, :restartPolicy], 'Never')
      pod_status[:phase] = "Failed"

      refute execute

      out.must_include "resque-worker Pod: Failed\n"
      out.must_include "UNSTABLE"
    end

    it "waits for new pods when scheduling fails" do
      pod_status[:phase] = "Failed"

      refute execute

      out.must_include "resque-worker Pod: Missing\n"
      out.must_include "TIMEOUT, pods took too long to get live"
    end

    describe "replica sets" do
      it "stops when deployments replicaset has an error event" do
        # was unable to spawn pods
        pod_reply[:items].clear
        replica_sets_reply[:items] << {
          kind: "ReplicaSet",
          metadata: {
            name: "foo",
            namespace: "staging",
            labels: {deploy_group_id: deploy_group.id.to_s, role_id: kubernetes_roles(:resque_worker).id.to_s}
          }
        }

        # because of this event
        request = stub_request(:get, %r{http://foobar.server/api/v1/namespaces/staging/events}).
          to_return(
            body: {
              items: [
                {
                  type: 'Warning',
                  reason: 'Unhealthy',
                  message: "Warning FailedCreate: Error creating: admission webhook",
                  lastTimestamp: 1.minute.from_now.iso8601
                }
              ]
            }.to_json
          )

        refute execute, out
        out.must_include "ReplicaSet foo: Error event"
        assert_requested request, times: 10
      end
    end

    describe "percentage failure" do
      with_env KUBERNETES_ALLOW_NOT_READY_PERCENT: "50" # 1/2 allowed to fail (counting pods)

      it "fails when more than allowed amount fail" do
        worker_role.update_column(:replicas, 3) # 2 pod per role is pending = 66%
        refute execute, out
      end

      it "ignores when less than allowed amount fail" do
        worker_role.update_column(:replicas, 2) # 1 pod per role is pending = 50%
        assert execute, out
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

      refute execute, out

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

      refute execute, out

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

    it "fails when pod fails during stability phase" do
      good = pod_reply.deep_dup
      worker_is_unstable
      pod_responses.replace([{body: good.to_json}, {body: pod_reply.to_json}])

      refute execute, out

      out.must_include "READY"
      out.must_include "UNSTABLE, resources failed:"
      out.must_include "resque-worker Pod pod-resque-worker: Restarted"
    end

    it "fails when pod goes pending during stability phase" do
      good = pod_reply.deep_dup
      pod_status[:phase] = "Pending"
      pod_responses.replace([{body: good.to_json}, {body: pod_reply.to_json}])

      refute execute, out

      out.must_include "READY"
      out.must_include "UNSTABLE, resources not ready:"
      out.must_include "resque-worker Pod pod-resque-worker: Waiting (Pending, Unknown)"
    end

    it "shows error when pod could not be found" do
      pod_reply[:items].clear
      refute execute, out
      out.must_include "resque-worker Pod: Missing\n"
    end

    describe "with non-pod failures" do
      before do
        assert_request(
          :get,
          %r{http://foobar.server/api/v1/namespaces/staging/events.*Deployment},
          to_return: {
            body: {items: [{type: 'Warning', reason: 'NO', lastTimestamp: 1.minute.from_now.iso8601}]}.to_json
          },
          times: 4
        )
      end

      it "fails when non-pods have error events" do
        refute execute, out
        out.must_include "Deployment test-app-server events:\n  Warning NO"
      end

      it "does not count non-pods into allowed-not-ready" do
        with_env KUBERNETES_ALLOW_NOT_READY_PERCENT: "100" do
          refute execute, out
          out.must_include "Deployment test-app-server events:\n  Warning NO"
        end
      end
    end

    describe "an autoscaled role" do
      before do
        worker_role.kubernetes_role.update_column(:autoscaled, true)
      end

      it "only requires min pods to go live when a role is autoscaled" do
        pod_reply[:items] << pod_reply[:items].first.deep_dup # 2 pods exist because the deployment is autoscaled

        worker_is_unstable

        assert execute, out

        out.scan(/resque-worker Pod: Live/).count.must_equal 1, out
        out.must_include "SUCCESS"
      end

      it "fails when all pods fail" do
        extra_pod = pod_reply[:items].first.deep_dup
        pod_reply[:items] << extra_pod

        worker_is_unstable
        extra_pod[:status][:containerStatuses].first[:restartCount] = 1

        refute execute, out

        out.scan(/resque-worker Pod: Restarted/).count.must_equal 1, out
        out.scan(/resque-worker Pod pod-resque-worker: Restarted/).count.must_equal 1, out
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
      let(:rollback_instructions) { "Rollback on failure" }

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

        refute execute, out

        out.must_include "resque-worker Pod: Restarted"
        out.must_include "UNSTABLE"
        out.must_include rollback_indicator
        out.must_include rollback_instructions
        out.must_include "DONE" # DONE is shown ... we got past the rollback
        out.wont_include "SUCCESS"
        out.wont_include "FAILED"
      end

      it "deletes when there was no previous deployed resource" do
        refute execute, out

        out.must_include "resque-worker Pod: Restarted"
        out.must_include "UNSTABLE"
        out.must_include "Deleting"
        out.wont_include rollback_indicator
        out.must_include "DONE" # DONE is shown ... we got past the rollback
        out.wont_include "SUCCESS"
        out.wont_include "FAILED"
      end

      it "does not crash when rollback fails" do
        Kubernetes::Resource::Base.any_instance.stubs(:revert).raises("Weird error")

        refute execute, out

        out.must_include "resque-worker Pod: Restarted"
        out.must_include "UNSTABLE"
        out.must_include "DONE" # DONE is shown ... we got past the rollback
        out.must_include "FAILED: Weird error" # rollback error cause is shown
      end

      it "does not rollback when deploy disabled it" do
        deploy.update_column(:kubernetes_rollback, false)
        Kubernetes::Resource::Base.any_instance.expects(:revert).never

        refute execute, out

        out.must_include "resque-worker Pod: Restarted"
        out.must_include "UNSTABLE"
        out.must_include "DONE" # DONE is shown ... we got past the rollback
        out.wont_include rollback_instructions
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

        refute execute, out

        # failed
        out.must_include "resque-worker Pod: Restarted"
        out.must_include "UNSTABLE"

        # correct debugging output
        out.scan(/pod-(\S+).*(?:events|logs)/).flatten.uniq.
          must_equal ["resque-worker"], out # logs+events only for bad pod
        out.must_match(
          /events:\s+Warning FailedScheduling: fit failure on node \(ip-1-2-3-4\)\s+fit failure on node \(ip-2-3-4-5\) x5\n\n/ # rubocop:disable Layout/LineLength
        ) # combined repeated events
        out.must_match /logs:\s+LOG-1/
        out.must_include "events:\n  Warning FailedScheduling"
        out.must_include "Pod 100 resque-worker Service some-project events:\n  Warning FailedScheduling:"
      end

      it "hides logs when requested" do
        stage.update_column :kubernetes_hide_error_logs, true
        refute execute
        out.wont_include "logs"
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

        refute execute, out

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

        refute execute, out

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

        refute execute, out

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
    let(:retries) { SamsonKubernetes::API_RETRIES }

    before do
      Kubernetes::DeployExecutor.any_instance.stubs(:build_selectors).returns([])
    end

    it "retries on failure" do
      Kubeclient::Client.any_instance.expects(:get_pods).times(retries + 1).raises(Kubeclient::HttpError.new(1, 2, 3))
      executor.instance_variable_set(:@release, kubernetes_releases(:test_release))
      assert_raises(Kubeclient::HttpError) { executor.send(:fetch_grouped, :pods, 'v1') }
    end

    it "retries on ssl failure" do
      Kubeclient::Client.any_instance.expects(:get_pods).times(retries + 1).raises(OpenSSL::SSL::SSLError.new)
      executor.instance_variable_set(:@release, kubernetes_releases(:test_release))
      assert_raises(OpenSSL::SSL::SSLError) { executor.send(:fetch_grouped, :pods, 'v1') }
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

  describe "#resource_statuses" do
    it "does not check status for static kinds" do
      doc = Kubernetes::ReleaseDoc.new(kubernetes_role: Kubernetes::Role.new)
      doc.send :resource_template=, [{"kind" => "Role"}]
      executor.expects(:fetch_grouped).returns [] # no pods found ... ideally we should not even look for pods
      executor.send(:resource_statuses, [doc]).must_equal []
    end
  end

  describe "#print_statuses" do
    let(:status) do
      s = Kubernetes::ResourceStatus.new(
        resource: nil,
        role: kubernetes_roles(:app_server),
        deploy_group: deploy_groups(:pod1),
        start: nil,
        kind: "Pod"
      )
      s.instance_variable_set(:@details, "Pending")
      s
    end

    it "renders" do
      executor.send(:print_statuses, "Hey:", [status], exact: false)
      out.must_equal "Hey:\n  Pod1 app-server Pod: Pending\n"
    end

    it "does not summarizes with moderate amount of pods" do
      executor.send(:print_statuses, "Hey:", Array.new(3) { status.dup }, exact: false)
      out.must_equal(
        "Hey:\n  Pod1 app-server Pod: Pending\n  Pod1 app-server Pod: Pending\n  Pod1 app-server Pod: Pending\n"
      )
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
      out.must_equal "Hey:\n  Pod1 app-server Pod: Pending x20\n"
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

  describe "#sum_event_group" do
    context "when counts are present" do
      let(:events) do
        [
          {count: 1},
          {count: 2}
        ]
      end

      it "sums the counts in the event_group" do
        executor.send(:sum_event_group, events).must_equal 3
      end
    end

    context "when counts are missing" do
      let(:events) do
        [
          {},
          {}
        ]
      end

      it "returns 0" do
        executor.send(:sum_event_group, events).must_equal 0
      end
    end
  end

  describe "#show_logs_on_deploy_if_requested" do
    it "prints errors but continues to not block the deploy" do
      Kubernetes::DeployExecutor.any_instance.stubs(:build_selectors).returns([])
      Samson::ErrorNotifier.expects(:notify).returns("Details")
      executor.send(:show_logs_on_deploy_if_requested, 123)
      output.string.must_equal "  Error showing logs: Details\n"
    end
  end

  describe "#too_many_not_ready" do
    let(:log_string) { "Ignored" }
    let(:statuses) do
      Array.new(10) do
        s = Kubernetes::ResourceStatus.new(
          resource: {},
          role: "R1",
          deploy_group: deploy_groups(:pod1),
          prerequisite: false,
          start: nil,
          kind: "Pod"
        )
        s.instance_variable_set(:@live, true)
        s
      end
    end

    it "returns nil when everything is ready" do
      executor.send(:too_many_not_ready, statuses).must_be_nil
    end

    it "allows no failures when percent is not set" do
      statuses[0].instance_variable_set(:@live, false)
      executor.send(:too_many_not_ready, statuses).size.must_equal 1
    end

    it "does not blow up on empty" do
      executor.send(:too_many_not_ready, []).must_be_nil
    end

    describe "when given percentage" do
      with_env KUBERNETES_ALLOW_NOT_READY_PERCENT: "30"

      it "allows given percentage" do
        3.times { |i| statuses[i].instance_variable_set(:@live, false) }
        executor.send(:too_many_not_ready, statuses).must_be_nil
      end

      it "allows fails over given percentage" do
        4.times { |i| statuses[i].instance_variable_set(:@live, false) }
        executor.send(:too_many_not_ready, statuses).size.must_equal 4
      end

      it "groups by role" do
        statuses[0].instance_variable_set(:@live, false)
        statuses[0].instance_variable_set(:@role, "R2") # R2 is 100% dead
        executor.send(:too_many_not_ready, statuses).size.must_equal 1
      end

      it "fails when non-pods are not-ready" do
        statuses[0].instance_variable_set(:@live, false)
        statuses[0].instance_variable_set(:@kind, "ConfigMap")
        executor.send(:too_many_not_ready, statuses).size.must_equal 1
      end

      it "does not blow up on empty" do
        executor.send(:too_many_not_ready, []).must_be_nil
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

    let(:deployments_url) { "#{origin}/apis/apps/v1/namespaces/pod1/deployments" }
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
