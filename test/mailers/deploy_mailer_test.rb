require_relative '../test_helper'

describe DeployMailer do
  let(:stage) { stages(:test_staging) }
  let(:deploy) { deploys(:succeeded_test) }
  let(:user) { users(:admin) }
  subject { ActionMailer::Base.deliveries.last }

  def stub_empty_changeset
    changeset = stub_everything(files: [], commits: [], pull_requests: [])
    Deploy.any_instance.stubs(:changeset).returns(changeset)
  end

  describe "#deploy_email" do
    before do
      stage.update_attributes!(notify_email_address: 'test@test.com')
      stub_empty_changeset
      DeployMailer.deploy_email(deploy).deliver_now
    end

    it 'is from deploys@' do
      subject.from.must_equal(['deploys@samson-deployment.com'])
    end

    it 'sends to notify_email_address' do
      subject.to.must_equal(['test@test.com'])
    end

    it 'sets a subject' do
      subject.subject.wont_be_empty
    end
  end

  describe "#bypass_email" do
    let(:jira_address) { "" }

    before do
      BuddyCheck.stubs(:bypass_email_address).returns("test1@test.com")
      BuddyCheck.stubs(:bypass_jira_email_address).returns(jira_address)

      user.update_attributes!(email: 'user_email@test.com')

      stub_empty_changeset

      DeployMailer.bypass_email(deploy, user).deliver_now
    end

    it 'is from deploys@' do
      subject.from.must_equal(['deploys@samson-deployment.com'])
    end

    it 'sends to bypass_email_address' do
      subject.to.must_equal(['test1@test.com'])
    end

    it 'CCs user email' do
      subject.cc.must_equal(['user_email@test.com'])
    end

    it 'sets a bypass subject' do
      subject.subject.must_match /BYPASS/
    end

    describe "with jira address" do
      let(:jira_address) { "test3@test.com" }

      it 'sends to bypass_email_address, jira_email_address' do
        subject.to.must_equal(['test1@test.com', 'test3@test.com'])
      end
    end
  end

  describe "#deploy_failed_email" do
    it "sends" do
      stub_empty_changeset
      DeployMailer.deploy_failed_email(deploy, ["foo@bar.com"]).deliver_now
      subject.subject.must_equal "[AUTO-DEPLOY][DEPLOY] Super Admin deployed Project to Staging (staging)"
    end
  end
end
