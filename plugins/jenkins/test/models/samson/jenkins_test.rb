# frozen_string_literal: true
# rubocop:disable Layout/LineLength
require_relative '../../test_helper'

SingleCov.covered! uncovered: 2

describe Samson::Jenkins do
  def stub_crumb
    stub_request(:get, "http://www.test-url.com/api/json?tree=useCrumbs").
      with(headers: {Authorization: 'Basic dXNlckB0ZXN0LmNvbTpqYXBpa2V5'}).
      to_return(body: '{"crumb": "fb171d526b9cc9e25afe80b356e12cb7", "crumbRequestField": ".crumb"}')
  end

  def stub_job_detail
    stub_request(:get, "http://www.test-url.com/job/test_job/api/json").
      with(headers: {Authorization: 'Basic dXNlckB0ZXN0LmNvbTpqYXBpa2V5'}).
      to_return(status: 200, body: json_response)
  end

  def stub_build_with_parameters(update_params)
    stub_request(:post, "http://www.test-url.com/job/test_job/buildWithParameters").
      with(
        body: {"buildStartedBy": "Super Admin", "originatedFrom": "Foo_Staging_staging", "commit": "abcabcaaabcabcaaabcabcaaabcabcaaabcabca1", "deployUrl": "http://www.test-url.com/projects/foo/deploys/#{deploy.id}", "emails" => "super-admin@example.com", "tag" => nil}.merge(update_params),
        headers: {Authorization: 'Basic dXNlckB0ZXN0LmNvbTpqYXBpa2V5'}
      ).
      to_return(status: 200, body: "", headers: {}).to_timeout
  end

  def stub_build_with_parameters_when_autoconfig_is_enabled(update_params)
    stub_request(:post, "http://www.test-url.com/job/test_job/buildWithParameters").
      with(
        body: {"SAMSON_buildStartedBy": "Super Admin", "SAMSON_commit": "abcabcaaabcabcaaabcabcaaabcabcaaabcabca1", "SAMSON_deployUrl": "http://www.test-url.com/projects/foo/deploys/178003093", "SAMSON_emails": "super-admin@example.com", "SAMSON_originatedFrom": "Foo_Staging_staging", "SAMSON_tag": nil}.merge(update_params),
        headers: {
          Authorization: 'Basic dXNlckB0ZXN0LmNvbTpqYXBpa2V5'
        }
      ).
      to_return(status: 200, body: "", headers: {}).to_timeout
  end

  def stub_get_config(resp)
    stub_request(:get, "http://www.test-url.com/job/test_job/config.xml").
      with(headers: {Authorization: 'Basic dXNlckB0ZXN0LmNvbTpqYXBpa2V5'}).
      to_return(status: 200, body: resp)
  end

  def stub_post_config(body)
    stub_request(:post, "http://www.test-url.com/job/test_job/config.xml").
      with(body: body,
           headers: {Authorization: 'Basic dXNlckB0ZXN0LmNvbTpqYXBpa2V5'}).
      to_return(status: 200, body: "")
  end

  def stub_job(result: nil, url: nil, status: 200)
    stub_request(:get, "http://www.test-url.com/job/test_job/96//api/json").
      with(headers: {Authorization: 'Basic dXNlckB0ZXN0LmNvbTpqYXBpa2V5'}).
      to_return(status: status, body: build_detail_response.merge('result': result, 'url': url).to_json, headers: {}).to_timeout
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

  def stub_default
    stub_crumb
    stub_job_detail
    stub_build_with_parameters({})
    stub_build_detail("")
    stub_get_build_id_from_queue(123)
  end

  let(:deploy) { deploys(:succeeded_test) }
  let(:buddy) { users(:deployer_buddy) }
  let(:jenkins) { Samson::Jenkins.new('test_job', deploy) }
  let(:json_response) { '{"actions":[{"parameterDefinitions":[{"defaultParameterValue":{"value":"qarunner"},"description":"Replace the default value with the user id of the person starting this here, or doing the auto-check-in for Samson, or the person that should have message addressed to them","name":"buildStartedBy","type":"StringParameterDefinition"},{"defaultParameterValue":{"value":"Jenkins"},"description":"Replace the default value with the user id of the person starting this here, or doing the auto-check-in for Samson, or the person that should have message addressed to them","name":"originatedFrom","type":"StringParameterDefinition"}]},{},{},{},{}],"description":"","displayName":"rdhanoa_test_project","displayNameOrNull":null,"name":"rdhanoa_test_project","url":"https://jenkins.zende.sk/job/rdhanoa_test_project/","buildable":true,"builds":[{"number":95,"url":"https://jenkins.zende.sk/job/rdhanoa_test_project/95/"},{"number":94,"url":"https://jenkins.zende.sk/job/rdhanoa_test_project/94/"},{"number":93,"url":"https://jenkins.zende.sk/job/rdhanoa_test_project/93/"},{"number":92,"url":"https://jenkins.zende.sk/job/rdhanoa_test_project/92/"},{"number":91,"url":"https://jenkins.zende.sk/job/rdhanoa_test_project/91/"},{"number":87,"url":"https://jenkins.zende.sk/job/rdhanoa_test_project/87/"}],"color":"red","firstBuild":{"number":87,"url":"https://jenkins.zende.sk/job/rdhanoa_test_project/87/"},"healthReport":[{"description":"Build stability: All recent builds failed.","iconClassName":"icon-health-00to19","iconUrl":"health-00to19.png","score":0}],"inQueue":false,"keepDependencies":false,"lastBuild":{"number":95,"url":"https://jenkins.zende.sk/job/rdhanoa_test_project/95/"},"lastCompletedBuild":{"number":95,"url":"https://jenkins.zende.sk/job/rdhanoa_test_project/95/"},"lastFailedBuild":{"number":95,"url":"https://jenkins.zende.sk/job/rdhanoa_test_project/95/"},"lastStableBuild":{"number":87,"url":"https://jenkins.zende.sk/job/rdhanoa_test_project/87/"},"lastSuccessfulBuild":{"number":87,"url":"https://jenkins.zende.sk/job/rdhanoa_test_project/87/"},"lastUnstableBuild":null,"lastUnsuccessfulBuild":{"number":95,"url":"https://jenkins.zende.sk/job/rdhanoa_test_project/95/"},"nextBuildNumber":96,"property":[{},{},{"parameterDefinitions":[{"defaultParameterValue":{"name":"buildStartedBy","value":"qarunner"},"description":"Replace the default value with the user id of the person starting this here, or doing the auto-check-in for Samson, or the person that should have message addressed to them","name":"buildStartedBy","type":"StringParameterDefinition"},{"defaultParameterValue":{"name":"originatedFrom","value":"Jenkins"},"description":"Replace the default value with the user id of the person starting this here, or doing the auto-check-in for Samson, or the person that should have message addressed to them","name":"originatedFrom","type":"StringParameterDefinition"}]},{},{"wallDisplayBgPicture":null,"wallDisplayName":null}],"queueItem":null,"concurrentBuild":false,"downstreamProjects":[],"scm":{},"upstreamProjects":[]}' }
  let(:build_detail_response) { JSON.parse('{"actions":[{"parameters":[{"name":"buildStartedBy","value":"rupinder dhanoa"},{"name":"originatedFrom","value":"Production"}]},{"causes":[{"shortDescription":"Started by user Quality Assurance","userId":"qaauto@zendesk.com","userName":"Quality Assurance"}]},{"buildsByBranchName":{"refs/remotes/origin/master":{"buildNumber":110,"buildResult":null,"marked":{"SHA1":"77d6dac84c6e70dfae72e92fe3cc83ab53d0e28d","branch":[{"SHA1":"77d6dac84c6e70dfae72e92fe3cc83ab53d0e28d","name":"refs/remotes/origin/master"}]},"revision":{"SHA1":"77d6dac84c6e70dfae72e92fe3cc83ab53d0e28d","branch":[{"SHA1":"77d6dac84c6e70dfae72e92fe3cc83ab53d0e28d","name":"refs/remotes/origin/master"}]}}},"lastBuiltRevision":{"SHA1":"77d6dac84c6e70dfae72e92fe3cc83ab53d0e28d","branch":[{"SHA1":"77d6dac84c6e70dfae72e92fe3cc83ab53d0e28d","name":"refs/remotes/origin/master"}]},"remoteUrls":["git@github.com:zendesk/zendesk_browser_tests.git"],"scmName":""},{},{},{"failCount":0,"skipCount":0,"totalCount":1,"urlName":"testReport"},{}],"artifacts":[],"building":false,"description":null,"displayName":"#110","duration":89688,"estimatedDuration":91911,"executor":null,"fullDisplayName":"rdhanoa_test_project #110","id":"110","keepLog":false,"number":110,"queueId":8669,"result":"SUCCESS","timestamp":1429053438085,"url":"https://jenkins.zende.sk/job/rdhanoa_test_project/110/","builtOn":"","changeSet":{"items":[],"kind":"git"},"culprits":[]}') }

  before do
    # trigger initial request that does a version check (stub with a version that signals we support queueing)
    stub_request(:get, "http://www.test-url.com/").
      with(headers: {Authorization: 'Basic dXNlckB0ZXN0LmNvbTpqYXBpa2V5'}).
      to_return(headers: {"X-Jenkins": "1.600"})
    Samson::Jenkins.new(nil, nil).send(:client).get_root
  end

  describe ".deployed!" do
    let(:attributes) { JenkinsJob.last.attributes.except("id", "created_at", "updated_at") }

    before do
      Samson::Jenkins.any_instance.stubs(:build).returns 123
      deploy.stage.jenkins_job_names = 'foo,bar'
    end

    it "stores succeeded deploys" do
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
      stub_default
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

    it "does not fail when a user has no email" do
      buddy.update_column(:email, nil)
      deploy.update_column(:buddy_id, buddy.id)
      stub_default
      jenkins.build.must_equal 123
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

      it "does not send emails to addresses without domain that can come from committers" do
        with_env EMAIL_DOMAIN: 'example.com' do
          deploy.user.email = 'invalid'
          deploy.stubs(:buddy).returns(buddy)
          stub_build_with_parameters("emails": "deployerbuddy@example.com")
          stub_get_build_id_from_queue(1)
          jenkins.build.must_equal 1
        end
      end

      it "does not send emails to invalid addresses that can come from committers" do
        deploy.user.email = '49699333+dependabot[bot]@users.noreply.github.com'
        deploy.stubs(:buddy).returns(buddy)
        stub_build_with_parameters("emails": "deployerbuddy@example.com")
        stub_get_build_id_from_queue(1)
        jenkins.build.must_equal 1
      end

      it "includes committer emails when jenkins_email_committers flag is set" do
        deploy.stage.jenkins_email_committers = true
        stub_build_with_parameters("emails": 'super-admin@example.com,author1@example.com,author2@test.com,author3@example.comm,author4@example.co,AUTHOR5@EXAMPLE.COM')
        stub_get_build_id_from_queue(1)
        jenkins.build.must_equal 1
      end

      it "filters emails by EMAIL_DOMAIN" do
        with_env EMAIL_DOMAIN: 'example1.com' do
          stub_build_with_parameters("emails": "")
          stub_get_build_id_from_queue(1)
          jenkins.build.must_equal 1
        end
      end

      it "filters emails by EMAIL_DOMAIN when jenkins_email_committers flag is set" do
        with_env EMAIL_DOMAIN: 'example.com' do
          deploy.stage.jenkins_email_committers = true
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

  describe "with auto-config flag" do
    let(:jenkins_xml_new_job) do
      <<~XML
        <?xml version="1.0" encoding="UTF-8"?>
        <project>
          <description>This is a test line in Description.</description>
          <keepDependencies>false</keepDependencies>
          <properties>
            <com.sonyericsson.rebuild.RebuildSettings plugin="rebuild@1.25">
              <autoRebuild>false</autoRebuild>
              <rebuildDisabled>false</rebuildDisabled>
            </com.sonyericsson.rebuild.RebuildSettings>
          </properties>
          <scm class="hudson.scm.NullSCM"/>
          <canRoam>true</canRoam>
          <disabled>false</disabled>
          <blockBuildWhenDownstreamBuilding>false</blockBuildWhenDownstreamBuilding>
          <blockBuildWhenUpstreamBuilding>false</blockBuildWhenUpstreamBuilding>
          <triggers/>
          <concurrentBuild>false</concurrentBuild>
          <builders>
            <hudson.tasks.Shell>
              <command>echo "This is a test line in execute shell."</command>
            </hudson.tasks.Shell>
          </builders>
          <publishers/>
          <buildWrappers/>
        </project>
      XML
    end

    let(:jenkins_xml_configured) do
      <<~XML
        <?xml version="1.0" encoding="UTF-8"?>
        <project>
          <description>This is a test line in Description.
        #### SAMSON DESCRIPTION STARTS ####
        Following text is generated by Samson. Please do not edit manually.
        This job is triggered from following Samson projects and stages:
        * Foo - Staging
        Build Parameters starting with SAMSON_ are updated automatically by Samson. Please disable automatic updating of this jenkins job from the above mentioned samson projects before manually editing build parameters or description.
        #### SAMSON DESCRIPTION ENDS ####</description>
          <keepDependencies>false</keepDependencies>
          <properties>
            <com.sonyericsson.rebuild.RebuildSettings plugin="rebuild@1.25">
              <autoRebuild>false</autoRebuild>
              <rebuildDisabled>false</rebuildDisabled>
            </com.sonyericsson.rebuild.RebuildSettings>
          <hudson.model.ParametersDefinitionProperty><parameterDefinitions><hudson.model.StringParameterDefinition>
          <name>SAMSON_buildStartedBy</name>
          <description>Samson username of the person who started the deployment.</description>
          <defaultValue/>
        </hudson.model.StringParameterDefinition>
        <hudson.model.StringParameterDefinition>
          <name>SAMSON_originatedFrom</name>
          <description>Samson project + stage + commit hash from github tag</description>
          <defaultValue/>
        </hudson.model.StringParameterDefinition>
        <hudson.model.StringParameterDefinition>
          <name>SAMSON_commit</name>
          <description>Github commit hash of the change deployed.</description>
          <defaultValue/>
        </hudson.model.StringParameterDefinition>
        <hudson.model.StringParameterDefinition>
          <name>SAMSON_tag</name>
          <description>Github tags of the commit being deployed.</description>
          <defaultValue/>
        </hudson.model.StringParameterDefinition>
        <hudson.model.StringParameterDefinition>
          <name>SAMSON_deployUrl</name>
          <description>Samson url which triggered the current job.</description>
          <defaultValue/>
        </hudson.model.StringParameterDefinition>
        <hudson.model.StringParameterDefinition>
          <name>SAMSON_emails</name>
          <description>Emails of the committers, buddy and user for current deployment. Please see samson to exclude the committers email.</description>
          <defaultValue/>
        </hudson.model.StringParameterDefinition>
        </parameterDefinitions></hudson.model.ParametersDefinitionProperty></properties>
          <scm class="hudson.scm.NullSCM"/>
          <canRoam>true</canRoam>
          <disabled>false</disabled>
          <blockBuildWhenDownstreamBuilding>false</blockBuildWhenDownstreamBuilding>
          <blockBuildWhenUpstreamBuilding>false</blockBuildWhenUpstreamBuilding>
          <triggers/>
          <concurrentBuild>false</concurrentBuild>
          <builders>
            <hudson.tasks.Shell>
              <command>echo "This is a test line in execute shell."</command>
            </hudson.tasks.Shell>
          </builders>
          <publishers/>
          <buildWrappers/>
        </project>
      XML
    end

    let(:jenkins_xml_with_build_params_without_desc) do
      <<~XML
        <?xml version="1.0" encoding="UTF-8"?>
        <project>
          <description>This is a test line in Description.</description>
          <keepDependencies>false</keepDependencies>
          <properties>
            <com.sonyericsson.rebuild.RebuildSettings plugin="rebuild@1.25">
              <autoRebuild>false</autoRebuild>
              <rebuildDisabled>false</rebuildDisabled>
            </com.sonyericsson.rebuild.RebuildSettings>
          <hudson.model.ParametersDefinitionProperty><parameterDefinitions><hudson.model.StringParameterDefinition>
          <name>SAMSON_buildStartedBy</name>
          <description>Samson username of the person who started the deployment.</description>
          <defaultValue/>
        </hudson.model.StringParameterDefinition>
        <hudson.model.StringParameterDefinition>
          <name>SAMSON_originatedFrom</name>
          <description>Samson project + stage + commit hash from github tag</description>
          <defaultValue/>
        </hudson.model.StringParameterDefinition>
        <hudson.model.StringParameterDefinition>
          <name>SAMSON_commit</name>
          <description>Github commit hash of the change deployed.</description>
          <defaultValue/>
        </hudson.model.StringParameterDefinition>
        <hudson.model.StringParameterDefinition>
          <name>SAMSON_tag</name>
          <description>Github tags of the commit being deployed.</description>
          <defaultValue/>
        </hudson.model.StringParameterDefinition>
        <hudson.model.StringParameterDefinition>
          <name>SAMSON_deployUrl</name>
          <description>Samson url which triggered the current job.</description>
          <defaultValue/>
        </hudson.model.StringParameterDefinition>
        <hudson.model.StringParameterDefinition>
          <name>SAMSON_emails</name>
          <description>Emails of the committers, buddy and user for current deployment. Please see samson to exclude the committers email.</description>
          <defaultValue/>
        </hudson.model.StringParameterDefinition>
        </parameterDefinitions></hudson.model.ParametersDefinitionProperty></properties>
          <scm class="hudson.scm.NullSCM"/>
          <canRoam>true</canRoam>
          <disabled>false</disabled>
          <blockBuildWhenDownstreamBuilding>false</blockBuildWhenDownstreamBuilding>
          <blockBuildWhenUpstreamBuilding>false</blockBuildWhenUpstreamBuilding>
          <triggers/>
          <concurrentBuild>false</concurrentBuild>
          <builders>
            <hudson.tasks.Shell>
              <command>echo "This is a test line in execute shell."</command>
            </hudson.tasks.Shell>
          </builders>
          <publishers/>
          <buildWrappers/>
        </project>
      XML
    end

    let(:jenkins_xml_with_desc_without_params) do
      <<~XML
        <?xml version='1.0' encoding='UTF-8'?>
        <project>
          <description>This is a test line in Description.
        #### SAMSON DESCRIPTION STARTS ####
        Following text is generated by Samson. Please do not edit manually.
        This job is triggered from following Samson projects and stages:
        * Foo - Staging
        Build Parameters starting with SAMSON_ are updated automatically by Samson. Please disable automatic updating of this jenkins job from the above mentioned samson projects before manually editing build parameters or description.
        #### SAMSON DESCRIPTION ENDS ####</description>
          <keepDependencies>false</keepDependencies>
          <properties>
            <com.sonyericsson.rebuild.RebuildSettings plugin="rebuild@1.25">
              <autoRebuild>false</autoRebuild>
              <rebuildDisabled>false</rebuildDisabled>
            </com.sonyericsson.rebuild.RebuildSettings>
          </properties>
          <scm class="hudson.scm.NullSCM"/>
          <canRoam>true</canRoam>
          <disabled>false</disabled>
          <blockBuildWhenDownstreamBuilding>false</blockBuildWhenDownstreamBuilding>
          <blockBuildWhenUpstreamBuilding>false</blockBuildWhenUpstreamBuilding>
          <triggers/>
          <concurrentBuild>false</concurrentBuild>
          <builders>
            <hudson.tasks.Shell>
              <command>echo &quot;This is a test line in execute shell.&quot;</command>
            </hudson.tasks.Shell>
          </builders>
          <publishers/>
          <buildWrappers/>
        </project>
      XML
    end

    let(:jenkins_xml_with_string_build_params_other_then_samson) do
      <<~XML
        <?xml version="1.0" encoding="UTF-8"?>
        <project>
          <actions/>
          <description>This is a test line in Description.
        </description>
          <keepDependencies>false</keepDependencies>
          <properties>
            <com.sonyericsson.rebuild.RebuildSettings plugin="rebuild@1.25">
              <autoRebuild>false</autoRebuild>
              <rebuildDisabled>false</rebuildDisabled>
            </com.sonyericsson.rebuild.RebuildSettings>
            <hudson.model.ParametersDefinitionProperty>
              <parameterDefinitions>
                <hudson.model.StringParameterDefinition>
                  <name>test_param1</name>
                  <description/>
                  <defaultValue>def1</defaultValue>
                </hudson.model.StringParameterDefinition>
                <hudson.model.StringParameterDefinition>
                  <name>test_param2</name>
                  <description/>
                  <defaultValue>def2</defaultValue>
                </hudson.model.StringParameterDefinition>
              </parameterDefinitions>
            </hudson.model.ParametersDefinitionProperty>
          </properties>
          <scm class="hudson.scm.NullSCM"/>
          <canRoam>true</canRoam>
          <disabled>false</disabled>
          <blockBuildWhenDownstreamBuilding>false</blockBuildWhenDownstreamBuilding>
          <blockBuildWhenUpstreamBuilding>false</blockBuildWhenUpstreamBuilding>
          <triggers/>
          <concurrentBuild>false</concurrentBuild>
          <builders>
            <hudson.tasks.Shell>
              <command>echo "This is a test line in execute shell."</command>
            </hudson.tasks.Shell>
          </builders>
          <publishers/>
          <buildWrappers/>
        </project>
      XML
    end

    let(:jenkins_xml_configured_with_other_params) do
      <<~XML
        <?xml version="1.0" encoding="UTF-8"?>
        <project>
          <actions/>
          <description>This is a test line in Description.
        #### SAMSON DESCRIPTION STARTS ####
        Following text is generated by Samson. Please do not edit manually.
        This job is triggered from following Samson projects and stages:
        * Foo - Staging
        Build Parameters starting with SAMSON_ are updated automatically by Samson. Please disable automatic updating of this jenkins job from the above mentioned samson projects before manually editing build parameters or description.
        #### SAMSON DESCRIPTION ENDS ####</description>
          <keepDependencies>false</keepDependencies>
          <properties>
            <com.sonyericsson.rebuild.RebuildSettings plugin="rebuild@1.25">
              <autoRebuild>false</autoRebuild>
              <rebuildDisabled>false</rebuildDisabled>
            </com.sonyericsson.rebuild.RebuildSettings>
            <hudson.model.ParametersDefinitionProperty>
              <parameterDefinitions>
                <hudson.model.StringParameterDefinition>
                  <name>test_param1</name>
                  <description/>
                  <defaultValue>def1</defaultValue>
                </hudson.model.StringParameterDefinition>
                <hudson.model.StringParameterDefinition>
                  <name>test_param2</name>
                  <description/>
                  <defaultValue>def2</defaultValue>
                </hudson.model.StringParameterDefinition>
              <hudson.model.StringParameterDefinition>
          <name>SAMSON_buildStartedBy</name>
          <description>Samson username of the person who started the deployment.</description>
          <defaultValue/>
        </hudson.model.StringParameterDefinition>
        <hudson.model.StringParameterDefinition>
          <name>SAMSON_originatedFrom</name>
          <description>Samson project + stage + commit hash from github tag</description>
          <defaultValue/>
        </hudson.model.StringParameterDefinition>
        <hudson.model.StringParameterDefinition>
          <name>SAMSON_commit</name>
          <description>Github commit hash of the change deployed.</description>
          <defaultValue/>
        </hudson.model.StringParameterDefinition>
        <hudson.model.StringParameterDefinition>
          <name>SAMSON_tag</name>
          <description>Github tags of the commit being deployed.</description>
          <defaultValue/>
        </hudson.model.StringParameterDefinition>
        <hudson.model.StringParameterDefinition>
          <name>SAMSON_deployUrl</name>
          <description>Samson url which triggered the current job.</description>
          <defaultValue/>
        </hudson.model.StringParameterDefinition>
        <hudson.model.StringParameterDefinition>
          <name>SAMSON_emails</name>
          <description>Emails of the committers, buddy and user for current deployment. Please see samson to exclude the committers email.</description>
          <defaultValue/>
        </hudson.model.StringParameterDefinition>
        </parameterDefinitions>
            </hudson.model.ParametersDefinitionProperty>
          </properties>
          <scm class="hudson.scm.NullSCM"/>
          <canRoam>true</canRoam>
          <disabled>false</disabled>
          <blockBuildWhenDownstreamBuilding>false</blockBuildWhenDownstreamBuilding>
          <blockBuildWhenUpstreamBuilding>false</blockBuildWhenUpstreamBuilding>
          <triggers/>
          <concurrentBuild>false</concurrentBuild>
          <builders>
            <hudson.tasks.Shell>
              <command>echo "This is a test line in execute shell."</command>
            </hudson.tasks.Shell>
          </builders>
          <publishers/>
          <buildWrappers/>
        </project>
      XML
    end

    let(:jenkins_xml_with_some_samson_build_params) do
      <<~XML
        <?xml version='1.0' encoding='UTF-8'?>
        <project>
          <description>This is a test line in Description.
        #### SAMSON DESCRIPTION STARTS ####
        Following text is generated by Samson. Please do not edit manually.
        This job is triggered from following Samson projects and stages:
        * Example-project - s4
        Build Parameters starting with SAMSON_ are updated automatically by Samson. Please disable automatic updating of this jenkins job from the above mentioned samson projects before manually editing build parameters or description.
        #### SAMSON DESCRIPTION ENDS ####</description>
          <keepDependencies>false</keepDependencies>
          <properties>
            <com.sonyericsson.rebuild.RebuildSettings plugin="rebuild@1.25">
              <autoRebuild>false</autoRebuild>
              <rebuildDisabled>false</rebuildDisabled>
            </com.sonyericsson.rebuild.RebuildSettings>
            <hudson.model.ParametersDefinitionProperty>
              <parameterDefinitions>
                <hudson.model.StringParameterDefinition>
                  <name>test_param1</name>
                  <description></description>
                  <defaultValue>def1</defaultValue>
                </hudson.model.StringParameterDefinition>
                <hudson.model.StringParameterDefinition>
                  <name>test_param2</name>
                  <description></description>
                  <defaultValue>def2</defaultValue>
                </hudson.model.StringParameterDefinition>
                <hudson.model.StringParameterDefinition>
                  <name>SAMSON_buildStartedBy</name>
                  <description>Samson username of the person who started the deployment.</description>
                  <defaultValue></defaultValue>
                </hudson.model.StringParameterDefinition>
                <hudson.model.StringParameterDefinition>
                  <name>SAMSON_commit</name>
                  <description>Github commit hash of the change deployed.</description>
                  <defaultValue></defaultValue>
                </hudson.model.StringParameterDefinition>
                <hudson.model.StringParameterDefinition>
                  <name>SAMSON_deployUrl</name>
                  <description>Samson url which triggered the current job.</description>
                  <defaultValue></defaultValue>
                </hudson.model.StringParameterDefinition>
              </parameterDefinitions>
            </hudson.model.ParametersDefinitionProperty>
          </properties>
          <scm class="hudson.scm.NullSCM"/>
          <canRoam>true</canRoam>
          <disabled>false</disabled>
          <blockBuildWhenDownstreamBuilding>false</blockBuildWhenDownstreamBuilding>
          <blockBuildWhenUpstreamBuilding>false</blockBuildWhenUpstreamBuilding>
          <triggers/>
          <concurrentBuild>false</concurrentBuild>
          <builders>
            <hudson.tasks.Shell>
              <command>echo &quot;This is a test line in execute shell.&quot;</command>
            </hudson.tasks.Shell>
          </builders>
          <publishers/>
          <buildWrappers/>
        </project>
      XML
    end

    let(:jenkins_xml_configured_with_some_samson_build_params) do
      <<~XML
        <?xml version="1.0" encoding="UTF-8"?>
        <project>
          <description>This is a test line in Description.
        #### SAMSON DESCRIPTION STARTS ####
        Following text is generated by Samson. Please do not edit manually.
        This job is triggered from following Samson projects and stages:
        * Example-project - s4
        * Foo - Staging
        Build Parameters starting with SAMSON_ are updated automatically by Samson. Please disable automatic updating of this jenkins job from the above mentioned samson projects before manually editing build parameters or description.
        #### SAMSON DESCRIPTION ENDS ####</description>
          <keepDependencies>false</keepDependencies>
          <properties>
            <com.sonyericsson.rebuild.RebuildSettings plugin="rebuild@1.25">
              <autoRebuild>false</autoRebuild>
              <rebuildDisabled>false</rebuildDisabled>
            </com.sonyericsson.rebuild.RebuildSettings>
            <hudson.model.ParametersDefinitionProperty>
              <parameterDefinitions>
                <hudson.model.StringParameterDefinition>
                  <name>test_param1</name>
                  <description/>
                  <defaultValue>def1</defaultValue>
                </hudson.model.StringParameterDefinition>
                <hudson.model.StringParameterDefinition>
                  <name>test_param2</name>
                  <description/>
                  <defaultValue>def2</defaultValue>
                </hudson.model.StringParameterDefinition>
                <hudson.model.StringParameterDefinition>
                  <name>SAMSON_buildStartedBy</name>
                  <description>Samson username of the person who started the deployment.</description>
                  <defaultValue/>
                </hudson.model.StringParameterDefinition>
                <hudson.model.StringParameterDefinition>
                  <name>SAMSON_commit</name>
                  <description>Github commit hash of the change deployed.</description>
                  <defaultValue/>
                </hudson.model.StringParameterDefinition>
                <hudson.model.StringParameterDefinition>
                  <name>SAMSON_deployUrl</name>
                  <description>Samson url which triggered the current job.</description>
                  <defaultValue/>
                </hudson.model.StringParameterDefinition>
              <hudson.model.StringParameterDefinition>
          <name>SAMSON_originatedFrom</name>
          <description>Samson project + stage + commit hash from github tag</description>
          <defaultValue/>
        </hudson.model.StringParameterDefinition>
        <hudson.model.StringParameterDefinition>
          <name>SAMSON_tag</name>
          <description>Github tags of the commit being deployed.</description>
          <defaultValue/>
        </hudson.model.StringParameterDefinition>
        <hudson.model.StringParameterDefinition>
          <name>SAMSON_emails</name>
          <description>Emails of the committers, buddy and user for current deployment. Please see samson to exclude the committers email.</description>
          <defaultValue/>
        </hudson.model.StringParameterDefinition>
        </parameterDefinitions>
            </hudson.model.ParametersDefinitionProperty>
          </properties>
          <scm class="hudson.scm.NullSCM"/>
          <canRoam>true</canRoam>
          <disabled>false</disabled>
          <blockBuildWhenDownstreamBuilding>false</blockBuildWhenDownstreamBuilding>
          <blockBuildWhenUpstreamBuilding>false</blockBuildWhenUpstreamBuilding>
          <triggers/>
          <concurrentBuild>false</concurrentBuild>
          <builders>
            <hudson.tasks.Shell>
              <command>echo "This is a test line in execute shell."</command>
            </hudson.tasks.Shell>
          </builders>
          <publishers/>
          <buildWrappers/>
        </project>
      XML
    end

    let(:jenkins_xml_configured_with_updated_desc) do
      <<~XML
        <?xml version="1.0" encoding="UTF-8"?>
        <project>
          <description>This is a test line in Description.
        #### SAMSON DESCRIPTION STARTS ####
        Following text is generated by Samson. Please do not edit manually.
        This job is triggered from following Samson projects and stages:
        * Example-project - s4
        * Foo - Staging
        * Foo - test_stage2
        Build Parameters starting with SAMSON_ are updated automatically by Samson. Please disable automatic updating of this jenkins job from the above mentioned samson projects before manually editing build parameters or description.
        #### SAMSON DESCRIPTION ENDS ####</description>
          <keepDependencies>false</keepDependencies>
          <properties>
            <com.sonyericsson.rebuild.RebuildSettings plugin="rebuild@1.25">
              <autoRebuild>false</autoRebuild>
              <rebuildDisabled>false</rebuildDisabled>
            </com.sonyericsson.rebuild.RebuildSettings>
            <hudson.model.ParametersDefinitionProperty>
              <parameterDefinitions>
                <hudson.model.StringParameterDefinition>
                  <name>test_param1</name>
                  <description/>
                  <defaultValue>def1</defaultValue>
                </hudson.model.StringParameterDefinition>
                <hudson.model.StringParameterDefinition>
                  <name>test_param2</name>
                  <description/>
                  <defaultValue>def2</defaultValue>
                </hudson.model.StringParameterDefinition>
                <hudson.model.StringParameterDefinition>
                  <name>SAMSON_buildStartedBy</name>
                  <description>Samson username of the person who started the deployment.</description>
                  <defaultValue/>
                </hudson.model.StringParameterDefinition>
                <hudson.model.StringParameterDefinition>
                  <name>SAMSON_commit</name>
                  <description>Github commit hash of the change deployed.</description>
                  <defaultValue/>
                </hudson.model.StringParameterDefinition>
                <hudson.model.StringParameterDefinition>
                  <name>SAMSON_deployUrl</name>
                  <description>Samson url which triggered the current job.</description>
                  <defaultValue/>
                </hudson.model.StringParameterDefinition>
              <hudson.model.StringParameterDefinition>
          <name>SAMSON_originatedFrom</name>
          <description>Samson project + stage + commit hash from github tag</description>
          <defaultValue/>
        </hudson.model.StringParameterDefinition>
        <hudson.model.StringParameterDefinition>
          <name>SAMSON_tag</name>
          <description>Github tags of the commit being deployed.</description>
          <defaultValue/>
        </hudson.model.StringParameterDefinition>
        <hudson.model.StringParameterDefinition>
          <name>SAMSON_emails</name>
          <description>Emails of the committers, buddy and user for current deployment. Please see samson to exclude the committers email.</description>
          <defaultValue/>
        </hudson.model.StringParameterDefinition>
        </parameterDefinitions>
            </hudson.model.ParametersDefinitionProperty>
          </properties>
          <scm class="hudson.scm.NullSCM"/>
          <canRoam>true</canRoam>
          <disabled>false</disabled>
          <blockBuildWhenDownstreamBuilding>false</blockBuildWhenDownstreamBuilding>
          <blockBuildWhenUpstreamBuilding>false</blockBuildWhenUpstreamBuilding>
          <triggers/>
          <concurrentBuild>false</concurrentBuild>
          <builders>
            <hudson.tasks.Shell>
              <command>echo "This is a test line in execute shell."</command>
            </hudson.tasks.Shell>
          </builders>
          <publishers/>
          <buildWrappers/>
        </project>
      XML
    end

    before do
      stub_crumb
      stub_job_detail
      deploy.stage.jenkins_build_params = true
    end

    it "adds description and build params to job configuration" do
      stub_get_config(jenkins_xml_new_job)
      stub_build_with_parameters_when_autoconfig_is_enabled({})
      changes = jenkins.check_job_config
      assert changes.keys == ["build_params", "job_description"]
      new_conf = jenkins.build_job_config(changes)
      assert_equal jenkins_xml_configured, new_conf.to_xml.to_s
    end

    it "does nothing when description and build params are present in job configuration" do
      stub_get_config(jenkins_xml_configured)
      stub_build_with_parameters_when_autoconfig_is_enabled({})
      changes = jenkins.check_job_config
      assert changes.keys == []
      new_conf = jenkins.build_job_config(changes)
      assert_equal jenkins_xml_configured, new_conf.to_xml.to_s
    end

    it "adds description when build params are present" do
      stub_get_config(jenkins_xml_with_build_params_without_desc)
      stub_build_with_parameters_when_autoconfig_is_enabled({})
      changes = jenkins.check_job_config
      assert changes.keys == ["job_description"]
      new_conf = jenkins.build_job_config(changes)
      assert_equal jenkins_xml_configured, new_conf.to_xml.to_s
    end

    it "adds build params when only desc is present" do
      stub_get_config(jenkins_xml_with_desc_without_params)
      stub_build_with_parameters_when_autoconfig_is_enabled({})
      changes = jenkins.check_job_config
      assert changes.keys == ["build_params"]
      new_conf = jenkins.build_job_config(changes)
      assert_equal jenkins_xml_configured, new_conf.to_xml.to_s
    end

    it "adds samson build params when pre-configured params are present" do
      stub_get_config(jenkins_xml_with_string_build_params_other_then_samson)
      changes = jenkins.check_job_config
      assert changes.keys == ["build_params", "job_description"]
      new_conf = jenkins.build_job_config(changes)
      assert_equal jenkins_xml_configured_with_other_params, new_conf.to_xml.to_s
    end
    it "adds missing samson build params when some are present" do
      stub_get_config(jenkins_xml_with_some_samson_build_params)
      changes = jenkins.check_job_config
      assert changes.keys == ["build_params", "job_description"]
      new_conf = jenkins.build_job_config(changes)
      assert_equal jenkins_xml_configured_with_some_samson_build_params, new_conf.to_xml.to_s
    end

    it "updates desc when job is added to a new stage or project" do
      stub_get_config(jenkins_xml_configured_with_some_samson_build_params)
      deploy.stage.name = "test_stage2"
      stub_build_with_parameters_when_autoconfig_is_enabled("SAMSON_originatedFrom": "Foo_test_stage2_staging")
      changes = jenkins.check_job_config
      assert changes.keys == ["job_description"]
      new_conf = jenkins.build_job_config(changes)
      assert_equal jenkins_xml_configured_with_updated_desc, new_conf.to_xml.to_s
    end

    it "posts updated desc when job is added to a new stage or project" do
      stub_get_config(jenkins_xml_configured_with_some_samson_build_params)
      stub_post_config(jenkins_xml_configured_with_updated_desc)
      deploy.stage.name = "test_stage2"
      stub_build_with_parameters_when_autoconfig_is_enabled("SAMSON_originatedFrom": "Foo_test_stage2_staging")
      stub_get_build_id_from_queue(123)
      jenkins.build.must_equal 123
    end
  end
end
# rubocop:enable Layout/LineLength
