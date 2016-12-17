# frozen_string_literal: true
require_relative '../../test_helper'

SingleCov.covered!

describe Samson::Clair do
  share_database_connection_in_all_threads

  def execute!
    Samson::Clair.append_job_with_scan(job, 'latest')
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

    wait_for_threads

    job.reload
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
