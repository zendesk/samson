# frozen_string_literal: true
require_relative '../test_helper'

SingleCov.covered! unless defined?(Rake) # rake preloads all plugins

describe SamsonHyperclair do
  describe :after_docker_build do
    let(:build) { builds(:docker_build) }

    before { build.docker_build_job = jobs(:succeeded_test) }

    it "runs clair" do
      SamsonHyperclair.expects(:append_job_with_scan)
      Samson::Hooks.fire(:after_docker_build, build)
    end

    it "does not run clair when build failed" do
      build.docker_build_job.status = 'errored'
      SamsonHyperclair.expects(:append_job_with_scan).never
      Samson::Hooks.fire(:after_docker_build, build)
    end
  end

  describe '.append_job_with_scan' do
    share_database_connection_in_all_threads
    with_registries ["docker-registry.example.com"]

    def execute!
      SamsonHyperclair.append_job_with_scan(job, 'latest')
    end

    let(:job) { jobs(:succeeded_test) }

    around do |t|
      Tempfile.open('clair') do |f|
        f.write("#!/bin/bash\necho HELLO\nexit 0")
        f.close
        File.chmod 0o755, f.path
        with_env(HYPERCLAIR_PATH: f.path, DOCKER_REGISTRY: 'my.registry', &t)
      end
    end

    it "runs clair and reports success to the database" do
      execute!

      job.reload
      job.output.must_include "Clair scan: started"

      wait_for_threads

      job.output.must_include "Clair scan: success"
      job.output.must_include "HELLO"
    end

    it "runs clair and reports missing script to the database" do
      File.unlink ENV['HYPERCLAIR_PATH']

      execute!

      wait_for_threads

      job.reload
      job.output.must_include "Clair scan: errored"
      job.output.must_include "No such file or directory"
    end

    it "runs clair and reports failed script to the database" do
      File.write ENV['HYPERCLAIR_PATH'], "#!/bin/bash\necho WORLD\nexit 1"

      execute!

      wait_for_threads

      job.reload
      job.output.must_include "Clair scan: errored"
      job.output.must_include "WORLD"
    end
  end
end
