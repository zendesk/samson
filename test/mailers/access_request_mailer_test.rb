require_relative '../test_helper'

SingleCov.covered!

describe AccessRequestMailer do
  include AccessRequestTestSupport

  describe 'sends email' do
    let(:user) { users(:viewer) }
    let(:address_list) { 'jira@example.com watchers@example.com' }
    let(:prefix) { 'SAMSON ACCESS' }
    let(:hostname) { 'localhost' }
    let(:manager_email) { 'manager@example.com' }
    let(:reason) { 'Dummy reason.' }
    let(:role) { Role::DEPLOYER }
    subject { ActionMailer::Base.deliveries.last }

    before do
      enable_access_request(address_list, prefix)
    end

    after { restore_access_request_settings }

    describe 'multiple projects' do
      before do
        Project.any_instance.stubs(:valid_repository_url).returns(true)
        Project.create!(name: 'Second project', repository_url: 'git://foo.com:hello/world.git')
        AccessRequestMailer.access_request_email(
          hostname, user, manager_email, reason, Project.all.pluck(:id), role.id
        ).deliver_now
      end

      it 'has correct sender and recipients' do
        subject.from.must_equal [user.email]
        subject.to.must_equal address_list.split
        subject.cc.must_equal [manager_email]
      end

      it 'has a correct subject' do
        subject.subject.must_match /#{user.name}/
        subject.subject.must_match /#{role.display_name}/
      end

      it 'includes relevant information in body' do
        subject.body.to_s.must_match /#{user.email}/
        subject.body.to_s.must_match /#{role.display_name}/
        subject.body.to_s.must_match /#{hostname}/
        subject.body.to_s.must_match /#{reason}/
        Project.all.each { |project| subject.body.to_s.must_match /#{project.name}/ }
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
          subject.to.must_equal [address_list]
          subject.cc.must_equal [manager_email]
        end
      end

      describe 'no address configured' do
        let(:address_list) { nil }
        it 'handles no configured email address' do
          subject.to.must_equal [manager_email]
          subject.cc.must_be_empty
        end
      end
    end

    describe 'single project' do
      before do
        AccessRequestMailer.access_request_email(
          hostname, user, manager_email, reason, [projects(:test).id], role.id
        ).deliver_now
      end

      it 'includes target project name in body' do
        subject.body.to_s.must_match /#{projects(:test).name}/
      end
    end
  end
end
