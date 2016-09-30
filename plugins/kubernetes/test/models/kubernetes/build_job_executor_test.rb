# frozen_string_literal: true
require_relative "../../test_helper"

# Skip the following lines:
# - Simple resetting tracking variables for the next loop when
#   there is an error creating a build job or getting/watching pod log
SingleCov.covered! uncovered: 3

describe Kubernetes::BuildJobExecutor do
  let(:output) { StringIO.new }
  let(:out) { output.string }
  let(:registry_info) do
    {
      serveraddress: Rails.application.config.samson.docker.registry,
      username: 'foo', password: 'bar', email: 'moo@cow.com'
    }
  end

  let(:build) { builds(:docker_build) }
  let(:job) { jobs(:succeeded_test) }
  let(:project) { job.project }

  let(:executor) { Kubernetes::BuildJobExecutor.new(output, job: job) }

  describe '#execute!' do
    def execute!(push: false)
      executor.execute!(
        build, project,
        tag: 'latest', push: push, registry: registry_info
      )
    end

    let(:client) { stub }
    let(:extension_client) { stub }

    before do
      Kubernetes::Cluster.any_instance.stubs(:client).returns client
      Kubernetes::Cluster.any_instance.stubs(:extension_client).returns extension_client
    end

    it 'fails when an invalid registry is passed in' do
      registry_info[:serveraddress] = ''
      extension_client.expects(:create_job).never
      extension_client.expects(:delete_job).never
      success, job_log = execute!
      refute success
      assert_empty job_log
    end

    describe 'when there is a valid config and registry information' do
      let(:build_job_config_path) { kubernetes_sample_file_path('kubernetes_job.yml') }
      let(:job_config_file) { read_kubernetes_sample_file('kubernetes_role_config_file.yml') }
      let(:labels) { {foo: 'bar'} }
      let(:build_config) do
        stub(job: {
          metadata: {
            name: 'test_job',
            namespace: 'test_ns',
            labels: labels
          },
          spec: {
            template: {
              metadata: {
                name: 'test_job',
                namespace: 'test_ns',
                labels: labels
              },
              spec: {
                containers: [{ name: 'test-job' }]
              }
            }
          }
        })
      end

      before do
        extension_client.expects(:delete_job).once
        Kubernetes::RoleConfigFile.expects(:new).returns build_config
      end

      around { |t| with_env "KUBE_BUILD_JOB_FILE": build_job_config_path, &t }

      it 'reads the job config file and populates correct job parameters, but fails to start a job' do
        extension_client.expects(:create_job).raises(KubeException.new(500, 'Server Error', {}))

        assert_raises(KubeException) { execute! }

        project_name_dash = project.permalink.tr('_', '-')
        assert_match(/^#{Regexp.quote(project_name_dash)}-docker-build-#{build.id}-[0-9a-f]{14}$/,
          build_config.job[:metadata][:name])

        labels_config = [build_config.job[:metadata][:labels], build_config.job[:spec][:template][:metadata][:labels]]
        labels_config.each do |v|
          assert_equal v[:project], project_name_dash
          assert_equal v[:role], 'docker-build-job'
          assert_equal v[:foo], 'bar'
        end

        assert_equal build_config.job[:spec][:template][:spec][:containers][0][:args],
          [project.repository_url, build.git_sha, project.docker_repo, 'latest', 'no', 'no']
        assert_equal build_config.job[:spec][:template][:spec][:containers][0][:env].length, 1
      end

      describe 'when the job resource is created' do
        let(:job_api_obj) { stub(failure?: false, complete?: true) }
        let(:job_pod) { stub(first: stub(name: stub, namespace: stub)) }
        let(:job_pod_log) { ['A long long log', 'A shorter log'] }
        let(:pod_api_obj) { stub(name: stub, namespace: stub) }

        before do
          extension_client.expects(:create_job).once
          extension_client.expects(:get_job).at_least_once
          client.expects(:get_pods).returns(job_pod).at_least_once
          client.expects(:watch_pod_log).with(
            pod_api_obj.name, pod_api_obj.namespace
          ).returns(job_pod_log).at_least_once
          Kubernetes::Api::Job.expects(:new).returns(job_api_obj).at_least_once
          Kubernetes::Api::Pod.expects(:new).returns(pod_api_obj).at_least_once
          job_api_obj.stubs(:name).returns 'job-123'
        end

        it 'returns a success status and a non-empty log when the job completes' do
          success, job_log = execute!

          assert success
          assert_equal(job_pod_log.join("\n") << "\n", job_log)
        end

        it 'returns a failure status and an empty log when the job fails' do
          job_api_obj.stubs(:failure?).returns true

          success, job_log = execute!
          refute success
          assert_empty job_log
        end

        it 'returns a failure status and an empty log when the job times out' do
          start = Time.now
          Time.stubs(:now).returns(start)
          executor.expects(:sleep).with { Time.stubs(:now).returns(start + 1.hour); true }
          job_api_obj.stubs(:complete?).returns false
          success, job_log = execute!

          refute success
          assert_empty job_log
        end

        it 'returns the job status when it fails to clean up the build job' do
          extension_client.unstub(:delete_job)
          extension_client.expects(:delete_job).raises(KubeException.new(404, 'Not Found', {}))
          success, job_log = execute!

          assert success
          assert_equal(job_pod_log.join("\n") << "\n", job_log)
        end

        describe "clair" do
          before { ActiveRecord::Base.stubs(connection: ActiveRecord::Base.connection) } # we update in another thread

          around do |t|
            Tempfile.open('clair') do |f|
              f.write("#!/bin/bash\necho HELLO\nexit 0")
              f.close
              File.chmod 0o755, f.path
              with_env(HYPERCLAIR_PATH: f.path, &t)
            end
          end

          it "runs clair and reports success to the database" do
            success, job_log = execute!
            job_log.wont_include "Clair"
            assert success

            wait_for_threads

            job = Job.first
            job.output.must_include "Clair scan: success"
            job.output.must_include "HELLO"
          end

          it "does not run clair when build failed" do
            job_api_obj.stubs(:failure?).returns true
            success, job_log = execute!
            job_log.wont_include "Clair"
            refute success

            wait_for_threads # just in case something goes wrong / to keep tests symmetric

            job = Job.first
            job.output.wont_include "Clair scan"
          end

          it "runs clair and reports missing script to the database" do
            File.unlink ENV['HYPERCLAIR_PATH']

            success, job_log = execute!
            job_log.wont_include "Clair"
            assert success

            wait_for_threads

            job = Job.first
            job.output.must_include "Clair scan: errored"
            job.output.must_include "No such file or directory"
          end

          it "runs clair and reports failed script to the database" do
            File.write ENV['HYPERCLAIR_PATH'], "#!/bin/bash\necho WORLD\nexit 1"

            success, job_log = execute!
            job_log.wont_include "Clair"
            assert success

            wait_for_threads

            job = Job.first
            job.output.must_include "Clair scan: errored"
            job.output.must_include "WORLD"
          end

          it "runs clair and reports timed out script to the database" do
            IO.any_instance.expects(:read).raises(Timeout::Error)
            Process.expects(:kill).times(2)
            Process.expects(:wait)

            success, job_log = execute!
            job_log.wont_include "Clair"
            assert success

            wait_for_threads

            job = Job.first
            job.output.must_include "Clair scan: errored"
            job.output.must_include "Timeout::Error"
          end
        end
      end
    end
  end
end
