require_relative '../../test_helper'

describe Samson::Jenkins do
  def stub_crumb
    stub_request(:get, "http://user%40test.com:japikey@www.test-url.com/api/json?tree=useCrumbs").
      to_return(:body => '{"crumb": "fb171d526b9cc9e25afe80b356e12cb7", "crumbRequestField": ".crumb"}')
  end

  def stub_job_detail
    stub_request(:get, "http://user%40test.com:japikey@www.test-url.com/job/test_job/api/json").
      to_return(:status => 200, :body => json_response)
  end

  def stub_build_with_parameters
    stub_request(:post, "http://user%40test.com:japikey@www.test-url.com/job/test_job/buildWithParameters").
      with(:body => {"buildStartedBy"=>"Super Admin", "originatedFrom"=>"Staging"}).
      to_return(:status => 200, :body => "", :headers => {}).to_timeout
  end

  # avoid polling logic
  def stub_build_detail(result)
    stub_request(:get, "http://user%40test.com:japikey@www.test-url.com/job/test_job/96//api/json").
      to_return(:status => 200, :body => build_detail_response.merge("result" => result).to_json, :headers => {}).to_timeout
  end

  def stub_get_build_id_from_queue(build_id)
    JenkinsApi::Client::Job.any_instance.expects(:get_build_id_from_queue).returns(build_id)
  end

  let(:deploy) { deploys(:succeeded_test) }
  let(:jenkins) { Samson::Jenkins.new('test_job', deploy)}
  let(:json_response) {'{"actions":[{"parameterDefinitions":[{"defaultParameterValue":{"value":"qarunner"},"description":"Replace the default value with the user id of the person starting this here, or doing the auto-check-in for Samson, or the person that should have message addressed to them","name":"buildStartedBy","type":"StringParameterDefinition"},{"defaultParameterValue":{"value":"Jenkins"},"description":"Replace the default value with the user id of the person starting this here, or doing the auto-check-in for Samson, or the person that should have message addressed to them","name":"originatedFrom","type":"StringParameterDefinition"}]},{},{},{},{}],"description":"","displayName":"rdhanoa_test_project","displayNameOrNull":null,"name":"rdhanoa_test_project","url":"https://jenkins.zende.sk/job/rdhanoa_test_project/","buildable":true,"builds":[{"number":95,"url":"https://jenkins.zende.sk/job/rdhanoa_test_project/95/"},{"number":94,"url":"https://jenkins.zende.sk/job/rdhanoa_test_project/94/"},{"number":93,"url":"https://jenkins.zende.sk/job/rdhanoa_test_project/93/"},{"number":92,"url":"https://jenkins.zende.sk/job/rdhanoa_test_project/92/"},{"number":91,"url":"https://jenkins.zende.sk/job/rdhanoa_test_project/91/"},{"number":87,"url":"https://jenkins.zende.sk/job/rdhanoa_test_project/87/"}],"color":"red","firstBuild":{"number":87,"url":"https://jenkins.zende.sk/job/rdhanoa_test_project/87/"},"healthReport":[{"description":"Build stability: All recent builds failed.","iconClassName":"icon-health-00to19","iconUrl":"health-00to19.png","score":0}],"inQueue":false,"keepDependencies":false,"lastBuild":{"number":95,"url":"https://jenkins.zende.sk/job/rdhanoa_test_project/95/"},"lastCompletedBuild":{"number":95,"url":"https://jenkins.zende.sk/job/rdhanoa_test_project/95/"},"lastFailedBuild":{"number":95,"url":"https://jenkins.zende.sk/job/rdhanoa_test_project/95/"},"lastStableBuild":{"number":87,"url":"https://jenkins.zende.sk/job/rdhanoa_test_project/87/"},"lastSuccessfulBuild":{"number":87,"url":"https://jenkins.zende.sk/job/rdhanoa_test_project/87/"},"lastUnstableBuild":null,"lastUnsuccessfulBuild":{"number":95,"url":"https://jenkins.zende.sk/job/rdhanoa_test_project/95/"},"nextBuildNumber":96,"property":[{},{},{"parameterDefinitions":[{"defaultParameterValue":{"name":"buildStartedBy","value":"qarunner"},"description":"Replace the default value with the user id of the person starting this here, or doing the auto-check-in for Samson, or the person that should have message addressed to them","name":"buildStartedBy","type":"StringParameterDefinition"},{"defaultParameterValue":{"name":"originatedFrom","value":"Jenkins"},"description":"Replace the default value with the user id of the person starting this here, or doing the auto-check-in for Samson, or the person that should have message addressed to them","name":"originatedFrom","type":"StringParameterDefinition"}]},{},{"wallDisplayBgPicture":null,"wallDisplayName":null}],"queueItem":null,"concurrentBuild":false,"downstreamProjects":[],"scm":{},"upstreamProjects":[]}'}
  let(:build_detail_response) { JSON.parse('{"actions":[{"parameters":[{"name":"buildStartedBy","value":"rupinder dhanoa"},{"name":"originatedFrom","value":"Production"}]},{"causes":[{"shortDescription":"Started by user Quality Assurance","userId":"qaauto@zendesk.com","userName":"Quality Assurance"}]},{"buildsByBranchName":{"refs/remotes/origin/master":{"buildNumber":110,"buildResult":null,"marked":{"SHA1":"77d6dac84c6e70dfae72e92fe3cc83ab53d0e28d","branch":[{"SHA1":"77d6dac84c6e70dfae72e92fe3cc83ab53d0e28d","name":"refs/remotes/origin/master"}]},"revision":{"SHA1":"77d6dac84c6e70dfae72e92fe3cc83ab53d0e28d","branch":[{"SHA1":"77d6dac84c6e70dfae72e92fe3cc83ab53d0e28d","name":"refs/remotes/origin/master"}]}}},"lastBuiltRevision":{"SHA1":"77d6dac84c6e70dfae72e92fe3cc83ab53d0e28d","branch":[{"SHA1":"77d6dac84c6e70dfae72e92fe3cc83ab53d0e28d","name":"refs/remotes/origin/master"}]},"remoteUrls":["git@github.com:zendesk/zendesk_browser_tests.git"],"scmName":""},{},{},{"failCount":0,"skipCount":0,"totalCount":1,"urlName":"testReport"},{}],"artifacts":[],"building":false,"description":null,"displayName":"#110","duration":89688,"estimatedDuration":91911,"executor":null,"fullDisplayName":"rdhanoa_test_project #110","id":"110","keepLog":false,"number":110,"queueId":8669,"result":"SUCCESS","timestamp":1429053438085,"url":"https://jenkins.zende.sk/job/rdhanoa_test_project/110/","builtOn":"","changeSet":{"items":[],"kind":"git"},"culprits":[]}') }


  before do
    # trigger initial request that does a version check (stub with a version that signals we support queueing)
    stub_request(:get, "http://user%40test.com:japikey@www.test-url.com/").
      to_return(:headers => {"X-Jenkins" => "1.600"})
    Samson::Jenkins.new(nil, nil).send(:client).get_root
  end

  describe "#build" do
    it "returns a job number when jenkins starts a build" do
      stub_crumb
      stub_job_detail
      stub_build_with_parameters
      stub_build_detail("")
      stub_get_build_id_from_queue(123)

      jenkins.build.must_equal 123
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
  end
end
