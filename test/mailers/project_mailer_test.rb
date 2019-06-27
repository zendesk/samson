# frozen_string_literal: true
require_relative '../test_helper'

SingleCov.covered!

class ProjectMailerTest < ActionMailer::TestCase
  let(:user) { users(:admin) }
  let(:project) { projects(:test) }

  describe "#created_email" do
    it "contains user and project name" do
      ProjectMailer.created_email('foo@exmaple.com', user, project).deliver_now
      mail_sent = ActionMailer::Base.deliveries.last
      assert mail_sent.subject.include?('Foo')
      assert mail_sent.body.include?('Admin')
      assert mail_sent.body.include?('Foo')
    end
  end

  describe "#deleted_email" do
    it "contains user and project name" do
      ProjectMailer.deleted_email('foo@exmaple.com', user, project).deliver_now
      mail_sent = ActionMailer::Base.deliveries.last
      assert mail_sent.subject.include?('Foo')
      assert mail_sent.body.include?('Admin')
      assert mail_sent.body.include?('Foo')
    end
  end
end
