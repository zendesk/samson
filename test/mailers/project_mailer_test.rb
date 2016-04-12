require_relative '../test_helper'

SingleCov.covered!

class ProjectMailerTest < ActionMailer::TestCase
  let(:user) { users(:admin) }
  let(:project) { projects(:test) }

  it "contains user and project name" do
    ProjectMailer.created_email(user, project).deliver_now
    mail_sent = ActionMailer::Base.deliveries.last
    assert mail_sent.subject.include?('Project')
    assert mail_sent.body.include?('Admin')
    assert mail_sent.body.include?('Project')
  end
end
