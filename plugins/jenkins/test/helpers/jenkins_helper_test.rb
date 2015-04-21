require_relative "../test_helper"

describe JenkinsHelper do
  def stub_jenkins_job_with_status(status)
    JenkinsJob.create!(name: "test_job", deploy_id: 11, jenkins_job_id: 111, status: status)
  end

  def stub_jenkins_job_without_status
    JenkinsJob.create!(name: "test_job", deploy_id: 11, jenkins_job_id: 111)
  end

  def stub_build_detail(result)
    stub_request(:get, "http://user%40test.com:japikey@www.test-url.com/job/test_job/111//api/json").
      to_return(:status => 200, :body => build_detail_response.merge("result" => result).to_json, :headers => {}).to_timeout
  end

  let(:deploy) { deploys(:succeeded_test) }
  let(:jenkins) { Samson::Jenkins.new('test_job', deploy) }
  let(:build_detail_response) { JSON.parse('{"actions":[{"parameters":[{"name":"buildStartedBy","value":"rupinder dhanoa"},{"name":"originatedFrom","value":"Production"}]},{"causes":[{"shortDescription":"Started by user Quality Assurance","userId":"qaauto@zendesk.com","userName":"Quality Assurance"}]},{"buildsByBranchName":{"refs/remotes/origin/master":{"buildNumber":110,"buildResult":null,"marked":{"SHA1":"77d6dac84c6e70dfae72e92fe3cc83ab53d0e28d","branch":[{"SHA1":"77d6dac84c6e70dfae72e92fe3cc83ab53d0e28d","name":"refs/remotes/origin/master"}]},"revision":{"SHA1":"77d6dac84c6e70dfae72e92fe3cc83ab53d0e28d","branch":[{"SHA1":"77d6dac84c6e70dfae72e92fe3cc83ab53d0e28d","name":"refs/remotes/origin/master"}]}}},"lastBuiltRevision":{"SHA1":"77d6dac84c6e70dfae72e92fe3cc83ab53d0e28d","branch":[{"SHA1":"77d6dac84c6e70dfae72e92fe3cc83ab53d0e28d","name":"refs/remotes/origin/master"}]},"remoteUrls":["git@github.com:zendesk/zendesk_browser_tests.git"],"scmName":""},{},{},{"failCount":0,"skipCount":0,"totalCount":1,"urlName":"testReport"},{}],"artifacts":[],"building":false,"description":null,"displayName":"#110","duration":89688,"estimatedDuration":91911,"executor":null,"fullDisplayName":"rdhanoa_test_project #110","id":"110","keepLog":false,"number":110,"queueId":8669,"result":"SUCCESS","timestamp":1429053438085,"url":"https://jenkins.zende.sk/job/rdhanoa_test_project/110/","builtOn":"","changeSet":{"items":[],"kind":"git"},"culprits":[]}') }

  describe "jenkins_status_panel" do
    it "shows Passed message when build status in database is PASSED" do
      jenkins_job = stub_jenkins_job_with_status("SUCCESS")
      html = jenkins_status_panel(deploy, jenkins_job)
      html.must_equal "<div class=\"alert alert-success\">Jenkins build test_job for Staging has Passed.</div>"
    end

    it "shows Failed message when build status in database is FAILED" do
      jenkins_job = stub_jenkins_job_with_status("FAILURE")
      html = jenkins_status_panel(deploy, jenkins_job)
      html.must_equal "<div class=\"alert alert-danger\">Jenkins build test_job for Staging has Failed.</div>"
    end

    it "shows Passed from jenkins when build starts" do
      jenkins_job = stub_jenkins_job_without_status
      stub_build_detail("SUCCESS")
      html = jenkins_status_panel(deploy, jenkins_job)
      html.must_equal "<div class=\"alert alert-success\">Jenkins build test_job for Staging has Passed.</div>"
    end

    it "shows Failed status from jenkins when build fails" do
      jenkins_job = stub_jenkins_job_without_status
      stub_build_detail("FAILURE")
      html = jenkins_status_panel(deploy, jenkins_job)
      html.must_equal "<div class=\"alert alert-danger\">Jenkins build test_job for Staging has Failed.</div>"
    end
  end
end
