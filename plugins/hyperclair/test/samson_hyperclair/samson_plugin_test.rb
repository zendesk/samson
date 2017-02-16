# frozen_string_literal: true
require_relative '../test_helper'
require 'ar_multi_threaded_transactional_tests'

SingleCov.covered!

describe SamsonHyperclair do
  let(:build) do
    build = builds(:docker_build)
    build.docker_build_job = jobs(:succeeded_test)
    build.docker_tag = 'latest'
    build
  end

  describe :after_docker_build do
    it "runs clair" do
      SamsonHyperclair.expects(:append_build_job_with_scan)
      Samson::Hooks.fire(:after_docker_build, build)
    end

    it "does not run clair when build failed" do
      build.docker_repo_digest = nil
      SamsonHyperclair.expects(:append_build_job_with_scan).never
      Samson::Hooks.fire(:after_docker_build, build)
    end
  end

  describe '.append_build_job_with_scan' do
    let(:job) { build.docker_build_job }

    around { |t| ArMultiThreadedTransactionalTests.activate &t }
    with_registries ["docker-registry.example.com"]

    def execute!
      SamsonHyperclair.append_build_job_with_scan(build)
    end

    around do |t|
      Tempfile.open('clair') do |f|
        f.write("#!/bin/bash\necho HELLO\necho OUT $@\nexit 0")
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
      job.output.must_include "\nHELLO\nOUT docker-registry.example.com/test@sha256:5f1d7"
    end

    it "runs clair with external build" do
      build.docker_build_job = nil
      execute!
      wait_for_threads
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
