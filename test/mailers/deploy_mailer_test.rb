require_relative '../test_helper'

describe DeployMailer do

  describe "deploy email" do
    let(:stage) { stages(:test_staging) }
    let(:deploy) { Deploy.create!(stage: stage, job: job, reference: 'master') }

    let(:job) do
      Job.create!(command: 'true', project: projects(:test), user: users(:admin))
    end

    before do
      stage.update_attributes!(notify_email_address: 'test@test.com')

      changeset = stub_everything(files: [], commits: [], pull_requests: [])
      Changeset.stubs(:find).returns(changeset)

      DeployMailer.deploy_email(stage, deploy).deliver
    end

    subject do
      ActionMailer::Base.deliveries.first
    end

    it 'is from deploys@' do
      subject.from.must_equal(['deploys@zendesk.com'])
    end

    it 'sends to notify_email_address' do
      subject.to.must_equal(['test@test.com'])
    end

    it 'sets a subject' do
      subject.subject.wont_be_empty
    end
  end

  describe "bypass email" do
    let(:stage) { stages(:test_staging) }
    let(:deploy) { Deploy.create!(stage: stage, job: job, reference: 'master') }
    let(:user) { users(:admin) }

    let(:job) do
      Job.create!(command: 'true', project: projects(:test), user: users(:admin))
    end

    before do
      BuddyCheck.stubs(:bypass_email_address).returns("test1@test.com")
      BuddyCheck.stubs(:bypass_jira_email_address).returns("")

      user.update_attributes!(email: 'user_email@test.com')

      changeset = stub_everything(files: [], commits: [], pull_requests: [])
      Changeset.stubs(:find).returns(changeset)

      DeployMailer.bypass_email(stage, deploy, user).deliver
    end

    subject do
      ActionMailer::Base.deliveries.first
    end

    it 'is from deploys@' do
      subject.from.must_equal(['deploys@zendesk.com'])
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
  end

  describe "bypass email, jira email" do
    let(:stage) { stages(:test_staging) }
    let(:deploy) { Deploy.create!(stage: stage, job: job, reference: 'master') }
    let(:user) { users(:admin) }

    let(:job) do
      Job.create!(command: 'true', project: projects(:test), user: users(:admin))
    end

    before do
      BuddyCheck.stubs(:bypass_email_address).returns("test1@test.com")
      BuddyCheck.stubs(:bypass_jira_email_address).returns("test3@test.com")

      user.update_attributes!(email: 'user_email@test.com')

      changeset = stub_everything(files: [], commits: [], pull_requests: [])
      Changeset.stubs(:find).returns(changeset)

      DeployMailer.bypass_email(stage, deploy, user).deliver
    end

    subject do
      ActionMailer::Base.deliveries.first
    end

    it 'sends to bypass_email_address, jira_email_address' do
      subject.to.must_equal(['test1@test.com', 'test3@test.com'])
    end

  end

end
