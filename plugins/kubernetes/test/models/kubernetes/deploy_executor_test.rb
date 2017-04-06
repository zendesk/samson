# frozen_string_literal: true
require_relative "../../test_helper"

SingleCov.covered!

describe Kubernetes::DeployExecutor do
  let(:output) { StringIO.new }
  let(:out) { output.string }
  let(:stage) { deploy.stage }
  let(:deploy) { job.deploy }
  let(:job) { jobs(:succeeded_test) }
  let(:project) { job.project }
  let(:build) { builds(:docker_build) }
  let(:deploy_group) { stage.deploy_groups.first }
  let(:executor) { Kubernetes::DeployExecutor.new(output, job: job, reference: 'master') }
  let(:log_url) { "http://foobar.server/api/v1/namespaces/staging/pods/pod-resque-worker/log?container=container1" }

  before do
    stage.update_column :kubernetes, true
    deploy.update_column :kubernetes, true
  end

  describe "#pid" do
    it "returns a fake pid" do
      executor.pid.must_include "Kubernetes"
    end
  end

  describe "#pgid" do
    it "returns a fake pid" do
      executor.pgid.must_include "Kubernetes"
    end
  end

  describe "#execute!" do
    def execute!
      stub_request(:get, %r{http://foobar.server/api/v1/namespaces/staging/pods\?}).
        to_return(body: pod_reply.to_json) # checks pod status to see if it's good
      executor.execute!
    end

    def stop_after_first_iteration
      executor.expects(:sleep).with { executor.stop!('FAKE-SGINAL'); true }
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
              phase: "Running", conditions: [{type: "Ready", status: "True"}],
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
            }
          }
        end
      }
    end
    let(:pod_status) { pod_reply[:items].first[:status] }
    let(:worker_role) { kubernetes_deploy_group_roles(:test_pod100_resque_worker) }
    let(:server_role) { kubernetes_deploy_group_roles(:test_pod100_app_server) }
    let(:deployments_url) { "http://foobar.server/apis/extensions/v1beta1/namespaces/staging/deployments" }
    let(:service_url) { "http://foobar.server/api/v1/namespaces/staging/services/some-project" }

    before do
      Kubernetes::DeployGroupRole.update_all(replicas: 1)
      job.update_column(:commit, build.git_sha) # this is normally done by JobExecution
      Kubernetes::Role.stubs(:configured_for_project).returns(project.kubernetes_roles)
      kubernetes_fake_raw_template
      Kubernetes::Cluster.any_instance.stubs(connection_valid?: true, namespace_exists?: true)
      deploy_group.create_cluster_deploy_group!(
        cluster: kubernetes_clusters(:test_cluster),
        namespace: 'staging',
        deploy_group: deploy_group
      )

      stub_request(:get, "#{deployments_url}/test-app-server").to_return(status: 404) # previous deploys ? -> none!
      stub_request(:get, "#{deployments_url}/test-resque-worker").to_return(status: 404) # previous deploys ? -> none!
      stub_request(:post, deployments_url).to_return(body: {}.to_json) # creates deployment
      stub_request(:put, "#{deployments_url}/test-resque-worker").
        to_return(body: {}.to_json) # updating deployment during delete for rollback

      executor.stubs(:sleep)
      stub_request(:get, %r{http://foobar.server/api/v1/namespaces/staging/events}).
        to_return(body: {items: []}.to_json)
      stub_request(:get, /#{Regexp.escape(log_url)}/)
      GitRepository.any_instance.stubs(:file_content).with('Dockerfile', anything).returns "FROM all"
      Kubernetes::TemplateFiller.any_instance.stubs(:set_image_pull_secrets)

      stub_request(:get, service_url).to_return(status: 404) # previous service ? -> none!
      stub_request(:post, File.dirname(service_url)).to_return(body: "{}")
      stub_request(:delete, service_url)

      Samson::Secrets::VaultClient.any_instance.stubs(:client).
        returns(stub(options: {address: 'https://test.hvault.server', ssl_verify: false}))
    end

    it "succeeds" do
      assert execute!
      out.must_include "resque-worker: Live\n"
      out.must_include "SUCCESS"
      out.wont_include "BigDecimal" # properly serialized configs
    end

    it "succeeds without a build" do
      Build.delete_all
      refute_difference 'Build.count' do
        GitRepository.any_instance.expects(:file_content).with('Dockerfile', anything).returns nil
        assert execute!
        out.must_include "Not creating a Build"
        out.must_include "resque-worker: Live\n"
        out.must_include "SUCCESS"
      end
    end

    it "can deploy roles with 0 replicas to disable them" do
      worker_role.update_column(:replicas, 0)
      assert execute!
      out.wont_include "resque-worker: Live\n"
      out.must_include "app-server: Live\n"
    end

    it "does not test for stability when not deploying any pods" do
      worker_role.update_column(:replicas, 0)
      server_role.update_column(:replicas, 0)
      assert execute!
      out.must_include "SUCCESS"
      out.wont_include "Stable"
      out.wont_include "Deploy status after"
    end

    describe "invalid configs" do
      before { build.delete } # build needs to be created -> assertion fails
      around { |test| refute_difference('Build.count') { refute_difference('Release.count', &test) } }

      it "fails before building when roles are invalid" do
        Kubernetes::ReleaseDoc.any_instance.unstub(:raw_template)
        GitRepository.any_instance.expects(:file_content).with { |file| file =~ /^kubernetes\// }.returns("oops: bad")

        e = assert_raises Samson::Hooks::UserError do
          refute execute!
        end
        e.message.must_include "Error found when parsing kubernetes/"
      end

      it "fails before building when secrets are not configured in the backend" do
        Kubernetes::TemplateFiller.any_instance.stubs(:needs_secret_puller?).returns(true)

        # overriding the stubbed value
        template = Kubernetes::ReleaseDoc.new.send(:raw_template)[0]
        template[:spec][:template][:metadata][:annotations] = {"secret/foo": "bar"}

        e = assert_raises Samson::Hooks::UserError do
          refute execute!
        end
        e.message.must_include "Failed to resolve secret keys:\n\tbar"
      end

      it "fails before building when env is not configured" do
        # overriding the stubbed value
        template = Kubernetes::ReleaseDoc.new.send(:raw_template)[0]
        template[:spec][:template][:metadata][:annotations] = {"samson/required_env": "FOO BAR"}

        e = assert_raises Samson::Hooks::UserError do
          refute execute!
        end
        e.message.must_include "Missing env variables FOO, BAR"
      end
    end

    describe "role settings" do
      it "uses configured role settings" do
        assert execute!
        doc = Kubernetes::Release.last.release_docs.sort_by(&:kubernetes_role).last
        config = server_role
        doc.replica_target.must_equal config.replicas
        doc.cpu.must_equal config.cpu
        doc.ram.must_equal config.ram
      end

      it "fails when role config is missing" do
        worker_role.delete
        e = assert_raises(Samson::Hooks::UserError) { execute! }
        e.message.must_equal(
          "Role resque-worker for Pod 100 is not configured, but in repo at 1a6f551a2ffa6d88e15eef5461384da0bfb1c194"
        )
      end

      it "fails when no role is setup in the project" do
        Kubernetes::Role.stubs(:configured_for_project).returns([worker_role])
        e = assert_raises(Samson::Hooks::UserError) { execute! }
        e.message.must_equal(
          "Could not find config files for Pod 100 kubernetes/app_server.yml, kubernetes/resque_worker.yml" \
          " at 1a6f551a2ffa6d88e15eef5461384da0bfb1c194"
        )
      end
    end

    describe "build" do
      before do
        build.update_column(:docker_repo_digest, nil)
      end

      it "fails when the build is not built" do
        e = assert_raises(Samson::Hooks::UserError) { execute! }
        e.message.must_equal "Build #{build.url} was created but never ran, run it manually."
        out.wont_include "Creating Build"
      end

      it "waits when build is running" do
        build.create_docker_job.update_column(:status, 'running')
        build.save!

        job = build.docker_build_job
        job.class.any_instance.expects(:reload).with do
          # inside wait loop ... pretend the build worked
          job.status = 'succeeded'
          build.update_column(:docker_repo_digest, 'somet-digest')
          true
        end.returns job

        assert execute!

        out.must_include "Waiting for Build #{build.url} to finish."
        out.must_include "SUCCESS"
      end

      it "fails when build job failed" do
        build.create_docker_job.update_column(:status, 'cancelled')
        build.save!
        e = assert_raises Samson::Hooks::UserError do
          execute!
        end
        e.message.must_equal "Build #{build.url} is cancelled, rerun it manually."
        out.wont_include "Creating Build"
      end

      describe "when build needs to be created" do
        before do
          build.update_column(:git_sha, 'something-else')
          Build.any_instance.stubs(:validate_git_reference)
        end

        it "succeeds when the build works" do
          DockerBuilderService.any_instance.expects(:run!).with do
            Build.last.create_docker_job.update_column(:status, 'succeeded')
            Build.last.update_column(:docker_repo_digest, 'some-sha')
            true
          end
          assert execute!
          out.must_include "SUCCESS"
          out.must_include "Creating Build for #{job.commit}"
          out.must_include "Build #{Build.last.url} is looking good"
        end

        it "reuses build when told to do so" do
          previous = deploys(:failed_staging_test)
          previous.update_column(:id, deploy.id - 1) # make previous_deploy work
          kubernetes_releases(:test_release).update_column(:deploy_id, previous.id) # find previous deploy
          build.update_column(:docker_repo_digest, 'ababababab') # make build succeeded
          deploy.update_column(:kubernetes_reuse_build, true)

          DockerBuilderService.any_instance.expects(:run!).never

          assert execute!
          out.must_include "SUCCESS"
          out.must_include "Build #{build.url} is looking good"
        end

        it "fails when the build fails" do
          DockerBuilderService.any_instance.expects(:run!).with do
            Build.any_instance.expects(:docker_build_job).at_least_once.returns Job.new(status: 'cancelled')
            true
          end
          e = assert_raises Samson::Hooks::UserError do
            execute!
          end
          e.message.must_equal "Build #{Build.last.url} is cancelled, rerun it manually."
          out.must_include "Creating Build for #{job.commit}.\n"
        end

        it "stops when deploy is stopped by user" do
          executor.stop!('FAKE-SIGNAL')
          DockerBuilderService.any_instance.expects(:run!).returns(true)
          refute execute!
          out.scan(/.*Build.*/).must_equal ["Creating Build for #{job.commit}."] # not waiting for build
          out.must_include "STOPPED"
        end
      end
    end

    describe "running a job before the deploy" do
      before do
        # we need multiple different templates here
        # make the worker a job and keep the app server
        Kubernetes::ReleaseDoc.any_instance.unstub(:raw_template)
        GitRepository.any_instance.stubs(:file_content).with('kubernetes/resque_worker.yml', anything).returns({
          'kind' => 'Job',
          'spec' => {
            'template' => {
              'metadata' => {'labels' => {'project' => 'foobar', 'role' => 'migrate'}},
              'spec' => {
                'containers' => [{'name' => 'job'}],
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
        GitRepository.any_instance.stubs(:file_content).with('kubernetes/app_server.yml', anything).
          returns(read_kubernetes_sample_file('kubernetes_deployment.yml'))

        # check if the job already exists ... it does not
        stub_request(:get, "http://foobar.server/apis/extensions/v1beta1/namespaces/staging/jobs/test-resque-worker").
          to_return(status: 404)

        # create job
        stub_request(:post, "http://foobar.server/apis/extensions/v1beta1/namespaces/staging/jobs").
          to_return(body: '{}')

        # mark the job as Succeeded
        pod_reply[:items][0][:status][:phase] = 'Succeeded'
      end

      it "runs only jobs" do
        kubernetes_roles(:app_server).destroy
        assert execute!
        out.must_include "resque-worker: Live\n"
        out.must_include "SUCCESS"
        out.wont_include "stability"
        out.wont_include "deploying jobs" # not announcing that we deploy jobs since there is nothing else
        out.wont_include "other roles" # not announcing that we have more to deploy
      end

      it "runs prerequisites and then the deploy" do
        assert execute!
        out.must_include "resque-worker: Live\n"
        out.must_include "SUCCESS"
        out.must_include "stability" # testing deploy for stability
        out.must_include "deploying prerequisite" # announcing that we deploy prerequisites first
        out.must_include "other roles" # announcing that we have more to deploy
      end

      it "fails when jobs fail" do
        executor.expects(:deploy_and_watch).returns false # jobs failed, they are the first execution
        refute execute!
        out.wont_include "SUCCESS"
        out.wont_include "stability"
        out.wont_include "other roles" # not announcing that we have more to deploy
      end
    end

    it "fails when release has errors" do
      Kubernetes::Release.any_instance.expects(:persisted?).at_least_once.returns(false)
      e = assert_raises(Samson::Hooks::UserError) { execute! }
      e.message.must_equal "Failed to create release: []" # inspected errros
    end

    it "shows status of each individual pod when there is more than 1 per deploy group" do
      worker_role.update_column(:replicas, 2)
      pod_reply[:items] << pod_reply[:items].first
      assert execute!
      out.scan(/resque-worker: Live/).count.must_equal 2
      out.must_include "SUCCESS"
    end

    it "stops the loop when stopping" do
      executor.stop!('FAKE-SIGNAL')
      refute execute!
      out.wont_include "SUCCESS"
      out.must_include "STOPPED"
    end

    it "waits when deploy is not running" do
      pod_status[:phase] = "Pending"
      pod_status.delete(:conditions)

      stop_after_first_iteration
      refute execute!

      out.must_include "resque-worker: Waiting (Pending, Unknown)\n"
      out.must_include "STOPPED"
    end

    it "stops when detecting a restart" do
      worker_is_unstable

      refute execute!

      out.must_include "resque-worker: Restarted\n"
      out.must_include "UNSTABLE"
    end

    it "stops when detecting a restart and pod goes missing" do
      worker_is_unstable
      Kubernetes::DeployExecutor::ReleaseStatus.any_instance.stubs(:pod)

      refute execute!

      out.must_include "resque-worker: Restarted\n"
      out.must_include "UNSTABLE"
    end

    it "stops when detecting a failure" do
      pod_status[:phase] = "Failed"

      refute execute!

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
                reason: 'FailedScheduling',
                message: "fit failure on node (ip-1-2-3-4)\nfit failure on node (ip-2-3-4-5)",
                metadata: {creationTimestamp: "2017-03-31T22:56:20Z"}
              }
            ]
          }.to_json
        )

      refute execute!

      out.must_include "resque-worker: Error\n"
      out.must_include "UNSTABLE"

      assert_requested request, times: 5 # fetches pod events once and once for 4 different resources
    end

    it "stops when taking too long to go live" do
      pod_status[:phase] = "Pending"
      timeout_after_first_iteration
      refute execute!
      out.must_include "TIMEOUT"
    end

    it "waits when less then exected pods are found" do
      Kubernetes::ReleaseDoc.any_instance.stubs(:desired_pod_count).returns(2)
      timeout_after_first_iteration
      refute execute!
      out.must_include "TIMEOUT"
    end

    it "waits when deploy is running but Unknown" do
      pod_status[:conditions][0][:status] = "False"

      stop_after_first_iteration
      refute execute!

      out.must_include "resque-worker: Waiting (Running, Unknown)\n"
      out.must_include "STOPPED"
    end

    it "fails when pod is failing to boot" do
      pod_status[:containerStatuses][0][:restartCount] = 1
      executor.instance_variable_set(:@testing_for_stability, 0)
      executor.expects(:raise).with("prerequisites should not check for stability") # ignore sanity check
      refute execute!
      out.must_include "resque-worker: Restarted"
      out.must_include "UNSTABLE"
    end

    # not sure if this will ever happen ...
    it "shows error when pod could not be found" do
      pod_reply[:items].clear

      stop_after_first_iteration
      refute execute!

      out.must_include "resque-worker: Missing\n"
      out.must_include "STOPPED"
    end

    describe "when rollback is needed" do
      let(:rollback_indicator) { "Rolling back" }

      before { worker_is_unstable }

      it "rolls back when previous resource existed" do
        stub_request(:get, service_url).to_return(body: {metadata: {uid: '123'}}.to_json)

        refute execute!

        out.must_include "resque-worker: Restarted\n"
        out.must_include "UNSTABLE"
        out.must_include rollback_indicator
        out.must_include "DONE" # DONE is shown ... we got past the rollback
        out.wont_include "SUCCESS"
        out.wont_include "FAILED"
      end

      it "deletes when there was no previous deployed resource" do
        refute execute!

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

        refute execute!

        out.must_include "resque-worker: Restarted\n"
        out.must_include "UNSTABLE"
        out.must_include "DONE" # DONE is shown ... we got past the rollback
        out.must_include "FAILED: Weird error" # rollback error cause is shown
      end

      it "does not rollback when deploy disabled it" do
        deploy.update_column(:kubernetes_rollback, false)
        Kubernetes::Resource::Deployment.any_instance.stubs(:revert).never

        refute execute!

        out.must_include "resque-worker: Restarted\n"
        out.must_include "UNSTABLE"
        out.must_include "DONE" # DONE is shown ... we got past the rollback
      end
    end

    describe "events and logs" do
      it "displays events and logs when deploy failed" do
        # worker restarted -> we request the previous logs
        stub_request(:get, "#{log_url}&previous=true").
          to_return(body: "LOG-1")

        stub_request(:get, %r{http://foobar.server/api/v1/namespaces/staging/events}).
          to_return(
            body: {
              items: [
                {
                  reason: 'FailedScheduling',
                  message: "fit failure on node (ip-1-2-3-4)\nfit failure on node (ip-2-3-4-5)",
                  count: 4,
                  metadata: {creationTimestamp: "2017-03-31T22:56:20Z"}
                },
                {
                  reason: 'FailedScheduling',
                  message: "fit failure on node (ip-2-3-4-5)\nfit failure on node (ip-1-2-3-4)",
                  count: 1,
                  metadata: {creationTimestamp: "2017-03-31T22:56:20Z"}
                }
              ]
            }.to_json
          )

        worker_is_unstable

        refute execute!

        # failed
        out.must_include "resque-worker: Restarted\n"
        out.must_include "UNSTABLE"

        # correct debugging output
        out.scan(/Pod 100 pod pod-(\S+)/).flatten.uniq.must_equal ["resque-worker:"] # logs and events only for bad pod
        out.must_match(
          /EVENTS:\s+FailedScheduling: fit failure on node \(ip-1-2-3-4\)\s+fit failure on node \(ip-2-3-4-5\) x4\n\n/
        ) # no repeated events
        out.must_match /LOGS:\s+LOG-1/
        out.must_include "RESOURCE EVENTS staging.some-project:\n  FailedScheduling:"
      end
    end
  end
end
