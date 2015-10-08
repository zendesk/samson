require_relative '../test_helper'

describe AccessRequestMailer do
  include AccessRequestTestSupport

  describe 'sends email' do
    let(:user) { users(:viewer) }
    let(:project) { projects(:test) }
    let(:address_list) { 'jira@example.com watchers@example.com' }
    let(:prefix) { 'SAMSON ACCESS' }
    let(:hostname) { 'localhost' }
    let(:manager_email) { 'manager@example.com' }
    let(:reason) { 'Dummy reason.' }
    subject { ActionMailer::Base.deliveries.last }

    before do
      enable_access_request(address_list, prefix)
      AccessRequestMailer.access_request_email(hostname, user, manager_email, reason, project.id).deliver_now
    end

    after { restore_access_request_settings }

    it 'is from deploys@' do
      subject.from.must_equal ['deploys@samson-deployment.com']
    end

    it 'sends to configured addresses' do
      subject.to.must_equal(address_list.split << manager_email)
    end

    it 'includes prefix in subject' do
      subject.subject.must_match /\[#{prefix}\]/
    end

    it 'includes name in subject' do
      subject.subject.must_match /#{user.name}/
    end

    it 'includes proper role in subject' do
      subject.subject.must_match /#{Role.find(user.role_id + 1).name}/
    end

    it 'includes email in body' do
      subject.body.to_s.must_match /#{user.email}/
    end

    it 'includes proper role in body' do
      subject.body.to_s.must_match /#{Role.find(user.role_id + 1).name}/
    end

    it 'includes host in body' do
      subject.body.to_s.must_match /#{hostname}/
    end

    it 'includes reason in body' do
      subject.body.to_s.must_match /#{reason}/
    end

    it 'includes target project in body' do
      subject.body.to_s.must_match /#{project.name}/
    end

    describe 'no subject prefix' do
      let(:prefix) { nil }
      it 'does not include brackets if no prefix configured' do
        subject.subject.wont_match /\[.*\]/
      end
    end

    describe 'single address configured' do
      let(:address_list) { 'jira@example.com' }
      it 'handles single email address configured' do
        subject.to.must_equal([address_list, manager_email])
      end
    end

    describe 'no address configured' do
      let(:address_list) { nil }
      it 'handles no configured email address' do
        subject.to.must_equal([manager_email])
      end
    end
  end
end
