require_relative '../test_helper'

describe DeployMailer do
  let(:project) { projects(:test) }
  let(:user) { users(:deployer) }
  let(:service) { DeployService.new(project, user) }
  let(:stage) { stages(:test_staging) }
  let(:reference) { 'master' }
  let(:job) {Job.create!(command: 'true', project: project, user: user) }
  let(:deploy) { Deploy.create!(stage: stage, job: job, reference: reference) }

  let(:buddy_is_deployer) { user }
  let(:buddy_is_other) { users(:deployer_buddy) }

  before do
    stage.update_attributes!(notify_email_address: 'test@test.com')

    changeset = stub_everything(files: [], commits: [], pull_requests: [])
    Changeset.stubs(:find).returns(changeset)
  end

  describe "bypass deploy" do
    before do
      service.confirm_deploy!(deploy, stage, reference, buddy_is_deployer)
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

    it 'sets a bypass subject' do
      subject.subject.must_match /BYPASS/
    end
  end

  describe "non-bypass deploy" do
    before do
      service.confirm_deploy!(deploy, stage, reference, buddy_is_other)
    end

    subject do
      ActionMailer::Base.deliveries.first
    end

    it 'does not generate a bypass mail' do
      subject.must_be_nil
    end
  end
end
