require 'test_helper'

class ProjectTest < ActiveSupport::TestCase
  it "generates a secure token when created" do
    project = Project.create!(name: "hello", repository_url: "world")
    project.token.wont_be_nil
  end
end
