# frozen_string_literal: true
require_relative '../test_helper'

SingleCov.covered!

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
      stub_empty_changeset
      DeployMailer.deploy_email(deploy, ['test@test.com']).deliver_now
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
    it "delivers" do
      stub_empty_changeset
      Samson::BuddyCheck.expects(:bypass_email_addresses).returns(["a@b.com"])
      DeployMailer.bypass_email(deploy, user).deliver_now
      subject.from.must_equal ['deploys@samson-deployment.com']
      subject.subject.must_include "BYPASS"
      subject.subject.must_include deploy.id.to_s
      subject.to.must_equal ["a@b.com"]
      subject.cc.must_equal ['admin@example.com']
    end
  end

  describe "#deploy_failed_email" do
    it "sends" do
      stub_empty_changeset
      DeployMailer.deploy_failed_email(deploy, ["foo@bar.com"]).deliver_now
      subject.subject.must_equal "[AUTO-DEPLOY][DEPLOY][##{deploy.id}] Super Admin deployed staging to Foo Staging"
    end
  end
end
