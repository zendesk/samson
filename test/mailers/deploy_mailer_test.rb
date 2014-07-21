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
      subject.from.must_equal(['deploys@samson-deployment.com'])
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

    let(:job) do
      Job.create!(command: 'true', project: projects(:test), user: users(:admin))
    end

    before do
      BuddyCheck.stubs(:bypass_email_address).returns("test1@test.com")

      changeset = stub_everything(files: [], commits: [], pull_requests: [])
      Changeset.stubs(:find).returns(changeset)

      DeployMailer.bypass_email(stage, deploy).deliver
    end

    subject do
      ActionMailer::Base.deliveries.first
    end

    it 'is from deploys@' do
      subject.from.must_equal(['deploys@samson-deployment.com'])
    end

    it 'sends to bypass_email_address' do
      subject.to.must_equal(['test1@test.com'])
    end

    it 'sets a bypass subject' do
      subject.subject.must_match /BYPASS/
    end
  end

end
