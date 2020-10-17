# frozen_string_literal: true
# rubocop:disable Layout/LineLength
require_relative "../test_helper"

SingleCov.covered!

describe JenkinsHelper do
  def stub_jenkins_job(status, url)
    JenkinsJob.create!(name: "test_job", deploy: deploy, jenkins_job_id: 111, status: status, url: url)
  end

  def stub_jenkins_job_without_status
    JenkinsJob.create!(name: "test_job", deploy: deploy, jenkins_job_id: 111)
  end

  def assert_build_detail(result, status: 200, &block)
    assert_request(
      :get, "http://www.test-url.com/job/test_job/111//api/json",
      with: {headers: {'Authorization' => 'Basic dXNlckB0ZXN0LmNvbTpqYXBpa2V5'}},
      to_return: {status: status, body: {result: result, url: job_url}.to_json, headers: {}},
      &block
    )
  end

  let(:deploy) { deploys(:succeeded_test) }
  let(:jenkins) { Samson::Jenkins.new('test_job', deploy) }
  let(:job_url) { "https://jenkins.zende.sk/job/test_job/110/" }

  describe "#jenkins_status_panel" do
    it "shows Passed message when build status in database is PASSED" do
      jenkins_job = stub_jenkins_job("SUCCESS", job_url)
      html = jenkins_status_panel(deploy, jenkins_job)
      html.must_equal "<a target=\"_blank\" rel=\"noopener\" href=\"#{job_url}\"><div class=\"alert alert-success\">Jenkins build test_job for Staging has passed.</div></a>"
    end

    it "shows Failed message when build status in database is FAILED" do
      jenkins_job = stub_jenkins_job("FAILURE", job_url)
      html = jenkins_status_panel(deploy, jenkins_job)
      html.must_equal "<a target=\"_blank\" rel=\"noopener\" href=\"#{job_url}\"><div class=\"alert alert-danger\">Jenkins build test_job for Staging has failed.</div></a>"
    end

    it "links to index page when no url was returned" do
      jenkins_job = stub_jenkins_job("FAILURE", nil)
      html = jenkins_status_panel(deploy, jenkins_job)
      html.must_equal "<a target=\"_blank\" rel=\"noopener\" href=\"http://www.test-url.com/job/test_job\"><div class=\"alert alert-danger\">Jenkins build test_job for Staging has failed.</div></a>"
    end

    it "shows Passed from jenkins when build starts" do
      jenkins_job = stub_jenkins_job_without_status
      assert_build_detail("SUCCESS") do
        html = jenkins_status_panel(deploy, jenkins_job)
        html.must_equal "<a target=\"_blank\" rel=\"noopener\" href=\"#{job_url}\"><div class=\"alert alert-success\">Jenkins build test_job for Staging has passed.</div></a>"
      end
    end

    it "shows Failed status from jenkins when build fails" do
      jenkins_job = stub_jenkins_job_without_status
      assert_build_detail("FAILURE") do
        html = jenkins_status_panel(deploy, jenkins_job)
        html.must_equal "<a target=\"_blank\" rel=\"noopener\" href=\"#{job_url}\"><div class=\"alert alert-danger\">Jenkins build test_job for Staging has failed.</div></a>"
      end
    end

    it "shows Unstable message when build status in database is UNSTABLE" do
      jenkins_job = stub_jenkins_job("UNSTABLE", job_url)
      html = jenkins_status_panel(deploy, jenkins_job)
      html.must_equal "<a target=\"_blank\" rel=\"noopener\" href=\"#{job_url}\"><div class=\"alert alert-warning\">Jenkins build test_job for Staging was unstable.</div></a>"
    end

    it "shows when the jenkins job is missing" do
      jenkins_job = stub_jenkins_job_without_status
      assert_build_detail("doesnt-matter", status: 404) do
        html = jenkins_status_panel(deploy, jenkins_job)
        html.must_equal "<a target=\"_blank\" rel=\"noopener\" href=\"#\"><div class=\"alert alert-warning\">Jenkins build test_job for Staging Requested component is not found on the Jenkins CI server.</div></a>"
      end
    end

    it "does not crash on missing status" do
      jenkins_job = stub_jenkins_job_without_status
      assert_build_detail(nil, status: 200) do
        jenkins_job.status = nil
        html = jenkins_status_panel(deploy, jenkins_job)
        html.must_include "Unable to retrieve status from jenkins"
      end
    end

    it "does not allow xss" do
      jenkins_job = stub_jenkins_job("SUCCESS", job_url)
      jenkins_job.name = "<script>FOOOO</script>"
      html = jenkins_status_panel(deploy, jenkins_job)
      html.must_equal "<a target=\"_blank\" rel=\"noopener\" href=\"#{job_url}\"><div class=\"alert alert-success\">Jenkins build &lt;script&gt;FOOOO&lt;/script&gt; for Staging has passed.</div></a>"
    end
  end
end
# rubocop:enable Layout/LineLength
