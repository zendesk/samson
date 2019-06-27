# frozen_string_literal: true
require_relative '../test_helper'

SingleCov.covered! uncovered: 1

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
    let(:mail_options) do
      {
        host: hostname,
        user: user,
        manager_email: manager_email,
        reason: reason,
        project_ids: Project.all.pluck(:id),
        role_id: role.id
      }
    end

    subject { ActionMailer::Base.deliveries.last }

    around { |t| enable_access_request address_list, email_prefix: prefix, &t }

    describe 'multiple projects' do
      before do
        Project.any_instance.stubs(:valid_repository_url).returns(true)
        Project.create!(name: 'Second project', repository_url: 'git://foo.com:hello/world.git')
        AccessRequestMailer.access_request_email(mail_options).deliver_now
      end

      it 'has correct sender and recipients' do
        subject.from.must_equal [user.email]
        subject.to.must_equal address_list.split
        subject.cc.must_equal [manager_email, user.email]
      end

      it 'has a correct subject' do
        subject.subject.must_include user.name
        subject.subject.must_include role.display_name
      end

      it 'includes relevant information in body' do
        subject.body.to_s.must_include user.email
        subject.body.to_s.must_include manager_email
        subject.body.to_s.must_include role.display_name
        subject.body.to_s.must_include hostname
        subject.body.to_s.must_include reason
        Project.all.each { |project| subject.body.to_s.must_include project.name }
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
          subject.cc.must_equal [manager_email, user.email]
        end
      end

      describe 'no address configured' do
        let(:address_list) { nil }
        it 'handles no configured email address' do
          subject.to.must_equal [manager_email]
          subject.cc.must_equal [user.email]
        end
      end
    end

    describe 'single project' do
      before do
        mail_options[:project_ids] = [projects(:test).id]
        AccessRequestMailer.access_request_email(mail_options).deliver_now
      end

      it 'includes target project name in body' do
        subject.body.to_s.must_include projects(:test).name
      end
    end
  end
end
