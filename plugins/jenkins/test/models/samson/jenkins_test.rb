# frozen_string_literal: true
# rubocop:disable Metrics/LineLength
require_relative '../../test_helper'

SingleCov.covered!

describe Samson::Jenkins do
  def stub_crumb
    stub_request(:get, "http://www.test-url.com/api/json?tree=useCrumbs").
      with(headers: {'Authorization' => 'Basic dXNlckB0ZXN0LmNvbTpqYXBpa2V5'}).
      to_return(body: '{"crumb": "fb171d526b9cc9e25afe80b356e12cb7", "crumbRequestField": ".crumb"}')
  end

  def stub_job_detail
    stub_request(:get, "http://www.test-url.com/job/test_job/api/json").
      with(headers: {'Authorization' => 'Basic dXNlckB0ZXN0LmNvbTpqYXBpa2V5'}).
      to_return(status: 200, body: json_response)
  end

  def stub_build_with_parameters(update_params)
    stub_request(:post, "http://www.test-url.com/job/test_job/buildWithParameters").
      with(
        body: {"buildStartedBy" => "Super Admin", "originatedFrom" => "Project_Staging_staging", "commit" => "abcabc1", "deployUrl" => "http://www.test-url.com/projects/foo/deploys/#{deploy.id}", "emails" => "super-admin@example.com"}.merge(update_params),
        headers: {'Authorization' => 'Basic dXNlckB0ZXN0LmNvbTpqYXBpa2V5'}
      ).
      to_return(status: 200, body: "", headers: {}).to_timeout
  end

  def stub_job(result: nil, url: nil, status: 200)
    stub_request(:get, "http://www.test-url.com/job/test_job/96//api/json").
      with(headers: {'Authorization' => 'Basic dXNlckB0ZXN0LmNvbTpqYXBpa2V5'}).
      to_return(status: status, body: build_detail_response.merge('result' => result, 'url' => url).to_json, headers: {}).to_timeout
  end

  # avoid polling logic
  def stub_build_detail(result, status: 200)
    stub_job(result: result, status: status)
  end

  def stub_build_url(url, status: 200)
    stub_job(url: url, status: status)
  end

  def stub_get_build_id_from_queue(build_id)
    JenkinsApi::Client::Job.any_instance.expects(:get_build_id_from_queue).returns(build_id)
  end

  def stub_add_changeset
    changeset = stub("changeset")
    commit1 = stub("commit1")
    commit1.stubs("author_email").returns("author1@example.com")
    commit2 = stub("commit2")
    commit2.stubs("author_email").returns("author2@test.com")
    commit3 = stub("commit3")
    commit3.stubs("author_email").returns("author3@example.comm")
    commit4 = stub("commit4")
    commit4.stubs("author_email").returns("author4@example.co")
    commit5 = stub("commit5")
    commit5.stubs("author_email").returns("AUTHOR5@EXAMPLE.COM")
    changeset.stubs(:commits).returns([commit1, commit2, commit3, commit4, commit5])
    deploy.stubs(:changeset).returns(changeset)
  end

  let(:deploy) { deploys(:succeeded_test) }
  let(:buddy) { users(:deployer_buddy) }
  let(:jenkins) { Samson::Jenkins.new('test_job', deploy) }
  let(:json_response) { '{"actions":[{"parameterDefinitions":[{"defaultParameterValue":{"value":"qarunner"},"description":"Replace the default value with the user id of the person starting this here, or doing the auto-check-in for Samson, or the person that should have message addressed to them","name":"buildStartedBy","type":"StringParameterDefinition"},{"defaultParameterValue":{"value":"Jenkins"},"description":"Replace the default value with the user id of the person starting this here, or doing the auto-check-in for Samson, or the person that should have message addressed to them","name":"originatedFrom","type":"StringParameterDefinition"}]},{},{},{},{}],"description":"","displayName":"rdhanoa_test_project","displayNameOrNull":null,"name":"rdhanoa_test_project","url":"https://jenkins.zende.sk/job/rdhanoa_test_project/","buildable":true,"builds":[{"number":95,"url":"https://jenkins.zende.sk/job/rdhanoa_test_project/95/"},{"number":94,"url":"https://jenkins.zende.sk/job/rdhanoa_test_project/94/"},{"number":93,"url":"https://jenkins.zende.sk/job/rdhanoa_test_project/93/"},{"number":92,"url":"https://jenkins.zende.sk/job/rdhanoa_test_project/92/"},{"number":91,"url":"https://jenkins.zende.sk/job/rdhanoa_test_project/91/"},{"number":87,"url":"https://jenkins.zende.sk/job/rdhanoa_test_project/87/"}],"color":"red","firstBuild":{"number":87,"url":"https://jenkins.zende.sk/job/rdhanoa_test_project/87/"},"healthReport":[{"description":"Build stability: All recent builds failed.","iconClassName":"icon-health-00to19","iconUrl":"health-00to19.png","score":0}],"inQueue":false,"keepDependencies":false,"lastBuild":{"number":95,"url":"https://jenkins.zende.sk/job/rdhanoa_test_project/95/"},"lastCompletedBuild":{"number":95,"url":"https://jenkins.zende.sk/job/rdhanoa_test_project/95/"},"lastFailedBuild":{"number":95,"url":"https://jenkins.zende.sk/job/rdhanoa_test_project/95/"},"lastStableBuild":{"number":87,"url":"https://jenkins.zende.sk/job/rdhanoa_test_project/87/"},"lastSuccessfulBuild":{"number":87,"url":"https://jenkins.zende.sk/job/rdhanoa_test_project/87/"},"lastUnstableBuild":null,"lastUnsuccessfulBuild":{"number":95,"url":"https://jenkins.zende.sk/job/rdhanoa_test_project/95/"},"nextBuildNumber":96,"property":[{},{},{"parameterDefinitions":[{"defaultParameterValue":{"name":"buildStartedBy","value":"qarunner"},"description":"Replace the default value with the user id of the person starting this here, or doing the auto-check-in for Samson, or the person that should have message addressed to them","name":"buildStartedBy","type":"StringParameterDefinition"},{"defaultParameterValue":{"name":"originatedFrom","value":"Jenkins"},"description":"Replace the default value with the user id of the person starting this here, or doing the auto-check-in for Samson, or the person that should have message addressed to them","name":"originatedFrom","type":"StringParameterDefinition"}]},{},{"wallDisplayBgPicture":null,"wallDisplayName":null}],"queueItem":null,"concurrentBuild":false,"downstreamProjects":[],"scm":{},"upstreamProjects":[]}' }
  let(:build_detail_response) { JSON.parse('{"actions":[{"parameters":[{"name":"buildStartedBy","value":"rupinder dhanoa"},{"name":"originatedFrom","value":"Production"}]},{"causes":[{"shortDescription":"Started by user Quality Assurance","userId":"qaauto@zendesk.com","userName":"Quality Assurance"}]},{"buildsByBranchName":{"refs/remotes/origin/master":{"buildNumber":110,"buildResult":null,"marked":{"SHA1":"77d6dac84c6e70dfae72e92fe3cc83ab53d0e28d","branch":[{"SHA1":"77d6dac84c6e70dfae72e92fe3cc83ab53d0e28d","name":"refs/remotes/origin/master"}]},"revision":{"SHA1":"77d6dac84c6e70dfae72e92fe3cc83ab53d0e28d","branch":[{"SHA1":"77d6dac84c6e70dfae72e92fe3cc83ab53d0e28d","name":"refs/remotes/origin/master"}]}}},"lastBuiltRevision":{"SHA1":"77d6dac84c6e70dfae72e92fe3cc83ab53d0e28d","branch":[{"SHA1":"77d6dac84c6e70dfae72e92fe3cc83ab53d0e28d","name":"refs/remotes/origin/master"}]},"remoteUrls":["git@github.com:zendesk/zendesk_browser_tests.git"],"scmName":""},{},{},{"failCount":0,"skipCount":0,"totalCount":1,"urlName":"testReport"},{}],"artifacts":[],"building":false,"description":null,"displayName":"#110","duration":89688,"estimatedDuration":91911,"executor":null,"fullDisplayName":"rdhanoa_test_project #110","id":"110","keepLog":false,"number":110,"queueId":8669,"result":"SUCCESS","timestamp":1429053438085,"url":"https://jenkins.zende.sk/job/rdhanoa_test_project/110/","builtOn":"","changeSet":{"items":[],"kind":"git"},"culprits":[]}') }

  before do
    # trigger initial request that does a version check (stub with a version that signals we support queueing)
    stub_request(:get, "http://www.test-url.com/").
      with(headers: {'Authorization' => 'Basic dXNlckB0ZXN0LmNvbTpqYXBpa2V5'}).
      to_return(headers: {"X-Jenkins" => "1.600"})
    Samson::Jenkins.new(nil, nil).send(:client).get_root
  end

  describe ".deployed!" do
    let(:attributes) { JenkinsJob.last.attributes.except("id", "created_at", "updated_at") }

    before do
      Samson::Jenkins.any_instance.stubs(:build).returns 123
      deploy.stage.jenkins_job_names = 'foo,bar'
    end

    it "stores successful deploys" do
      assert_difference('JenkinsJob.count', +2) { Samson::Jenkins.deployed!(deploy) }
      attributes.must_equal(
        "jenkins_job_id" => 123,
        "name" => "bar",
        "status" => nil,
        "error" => nil,
        "deploy_id" => deploy.id,
        "url" => nil
      )
    end

    it "stores failed deploys" do
      Samson::Jenkins.any_instance.stubs(:build).returns "Whoops"
      assert_difference('JenkinsJob.count', +2) { Samson::Jenkins.deployed!(deploy) }

      attributes.must_equal(
        "jenkins_job_id" => nil,
        "name" => "bar",
        "status" => "STARTUP_ERROR",
        "error" => "Whoops",
        "deploy_id" => deploy.id,
        "url" => nil
      )
    end

    it "truncated too long error messages" do
      Samson::Jenkins.any_instance.stubs(:build).returns("a" * 999)
      assert_difference('JenkinsJob.count', +2) { Samson::Jenkins.deployed!(deploy) }
      attributes["error"].size.must_equal 255
    end

    it "skips stages with blank jenkins jobs" do
      deploy.stage.jenkins_job_names = ''
      Samson::Jenkins.any_instance.expects(:build).never
      Samson::Jenkins.deployed!(deploy)
    end

    it "skips stages with nil jenkins jobs" do
      deploy.stage.jenkins_job_names = nil
      Samson::Jenkins.any_instance.expects(:build).never
      Samson::Jenkins.deployed!(deploy)
    end

    it "skips failed deploys" do
      deploy.job.status = 'failed'
      Samson::Jenkins.any_instance.expects(:build).never
      Samson::Jenkins.deployed!(deploy)
    end
  end

  describe "#build" do
    it "returns a job number when jenkins starts a build" do
      stub_crumb
      stub_job_detail
      stub_build_with_parameters({})
      stub_build_detail("")
      stub_get_build_id_from_queue(123)

      jenkins.build.must_equal 123
    end

    it "returns an error on timeout" do
      stub_request(:get, "http://www.test-url.com/job/test_job/api/json").to_timeout
      jenkins.build.must_include "timely"
    end

    it "returns an error on api error" do
      stub_request(:get, "http://www.test-url.com/job/test_job/api/json").to_return(status: 500, body: "{}")
      jenkins.build.must_include "Problem while waiting"
    end

    describe "with env flags" do
      before(:each) do
        stub_crumb
        stub_job_detail
        stub_add_changeset
      end

      it "sends deployer and buddy emails to jenkins" do
        deploy.stubs(:buddy).returns(buddy)
        stub_build_with_parameters("emails": "super-admin@example.com,deployerbuddy@example.com")
        stub_get_build_id_from_queue(1)
        jenkins.build.must_equal 1
      end

      it "includes committer emails when JENKINS_NOTIFY_COMMITTERS is set" do
        with_env 'JENKINS_NOTIFY_COMMITTERS': "1" do
          stub_build_with_parameters("emails": 'super-admin@example.com,author1@example.com,author2@test.com,author3@example.comm,author4@example.co,AUTHOR5@EXAMPLE.COM')
          stub_get_build_id_from_queue(1)
          jenkins.build.must_equal 1
        end
      end

      it "filters emails by GOOGLE_DOMAIN" do
        with_env 'GOOGLE_DOMAIN': '@example1.com' do
          stub_build_with_parameters("emails": "")
          stub_get_build_id_from_queue(1)
          jenkins.build.must_equal 1
        end
      end

      it "filters emails by GOOGLE_DOMAIN when JENKINS_NOTIFY_COMMITTERS is set" do
        with_env 'GOOGLE_DOMAIN': '@example.com', 'JENKINS_NOTIFY_COMMITTERS': '1' do
          stub_build_with_parameters("emails": 'super-admin@example.com,author1@example.com,AUTHOR5@EXAMPLE.COM')
          stub_get_build_id_from_queue(1)
          jenkins.build.must_equal 1
        end
      end
    end
  end

  describe "#job_status" do
    it "returns SUCCESS when jenkins build is successful" do
      stub_build_detail("SUCCESS")
      jenkins.job_status(96).must_equal "SUCCESS"
    end

    it "returns FAILURE when jenkins build fails" do
      stub_build_detail("FAILURE")
      jenkins.job_status(96).must_equal "FAILURE"
    end

    it "returns not found when jenkins job is not found" do
      stub_build_detail('doesnt matter', status: 404)
      jenkins.job_status(96).must_equal "Requested component is not found on the Jenkins CI server."
    end
  end

  describe "#job_url" do
    it "returns a jenkins job url" do
      stub_build_url("https://jenkins.zende.sk/job/rdhanoa_test_project/96/")
      jenkins.job_url(96).must_equal "https://jenkins.zende.sk/job/rdhanoa_test_project/96/"
    end

    it "returns an error when the job is missing" do
      stub_build_url("https://jenkins.zende.sk/job/rdhanoa_test_project/96/", status: 404)
      jenkins.job_url(96).must_equal "#"
    end
  end
end
