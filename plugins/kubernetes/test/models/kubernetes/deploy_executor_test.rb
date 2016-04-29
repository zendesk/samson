require_relative "../../test_helper"

SingleCov.covered!

describe Kubernetes::DeployExecutor do
  let(:output) { StringIO.new }
  let(:out) { output.string }
  let(:stage) { deploy.stage }
  let(:deploy) { job.deploy }
  let(:job) { jobs(:succeeded_test) }
  let(:build) { builds(:docker_build) }
  let(:executor) { Kubernetes::DeployExecutor.new(output, job: job) }

  before do
    stage.update_column :kubernetes, true
    deploy.update_column :kubernetes, true
  end

  describe "#pid" do
    it "returns a fake pid" do
      executor.pid.must_include "Kubernetes"
    end
  end

  describe "#execute!" do
    def execute!
      stub_request(:get, %r{http://foobar.server/api/1/namespaces/staging/pods}).to_return(body: pod_reply.to_json) # checks pod status to see if it's good
      executor.execute!
    end

    def stop_after_first_iteration
      executor.expects(:sleep).with { executor.stop!('FAKE-SGINAL'); true }
    end

    let(:pod_reply) do
      {
        resourceVersion: "1",
        items: [{
          status: {
            phase: "Running", conditions: [{type: "Ready", status: "True"}],
            containerStatuses: [{restartCount: 0}]
          }
        }]
      }
    end
    let(:pod_status) { pod_reply[:items].first[:status] }

    before do
      job.update_column(:commit, build.git_sha) # this is normally done by JobExecution
      Kubernetes::ReleaseDoc.any_instance.stubs(raw_template: {'kind' => 'Deployment', 'spec' => {'template' => {'metadata' => {'labels' => {}}, 'spec' => {'containers' => [{}]}}}, 'metadata' => {'labels' => {}}}.to_yaml) # TODO: should inject that from current checkout and not fetch via github
      Kubernetes::Cluster.any_instance.stubs(connection_valid?: true, namespace_exists?: true)
      stage.deploy_groups.each do |dg|
        dg.create_cluster_deploy_group cluster: kubernetes_clusters(:test_cluster), namespace: 'staging', deploy_group: dg
      end
      stub_request(:get, "http://foobar.server/apis/extensions/v1beta1/namespaces/staging/deployments/").to_return(status: 404) # checks for previous deploys ... but there are none
      stub_request(:post, "http://foobar.server/apis/extensions/v1beta1/namespaces/staging/deployments").to_return(body: "{}") # creates deployment
      executor.stubs(:sleep)
    end

    it "succeeds" do
      assert execute!
      out.must_include "resque_worker: Live\n"
      out.must_include "SUCCESS"
    end

    it "fails when build is not found" do
      job.update_column(:commit, 'some-unfound-sha')
      e = assert_raises Samson::Hooks::UserError do
        refute execute!
      end
      e.message.must_equal "Build for sha some-unfound-sha does not exist, create it before deploying"
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

      out.must_include "resque_worker: Waiting (Pending, not Ready)\n"
      out.must_include "STOPPED"
    end

    it "waits when deploy is running but not ready" do
      pod_status[:conditions][0][:status] = "False"

      stop_after_first_iteration
      refute execute!

      out.must_include "resque_worker: Waiting (Running, not Ready)\n"
      out.must_include "STOPPED"
    end

    it "fails when release has errors" do
      Kubernetes::Release.any_instance.expects(:persisted?).at_least_once.returns(false)
      e = assert_raises Samson::Hooks::UserError do
        execute!
      end
      e.message.must_equal "Failed to create release: []" # inspected errros
    end

    it "fails when pod is failing to boot" do
      pod_status[:containerStatuses][0][:restartCount] = 1
      executor.instance_variable_set(:@testing_for_stability, 0)
      refute execute!
      out.must_include "resque_worker: Restarted"
      out.must_include "UNSTABLE - service is restarting"
    end

    # not sure if this will ever happen ...
    it "shows error when pod could not be found" do
      pod_reply[:items].clear

      stop_after_first_iteration
      refute execute!

      out.must_include "resque_worker: Missing\n"
      out.must_include "STOPPED"
    end
  end
end

