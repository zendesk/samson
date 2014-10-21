require_relative '../../test_helper'

describe Permalinkable, :model do
  describe "#generate_permalink" do
    let(:project_url) { "git://foo.com:hello/world.git" }

    it "generates a unique link" do
      project = Project.create!(name: "hello", repository_url: project_url)
      project.permalink.must_equal "world"
    end

    it "generates with id when not unique" do
      Project.create!(name: "hello", repository_url: project_url)
      project = Project.create!(name: "hello", repository_url: project_url)
      project.permalink.must_match /\Aworld-[a-f\d]+\Z/
    end

    it "removes invalid url characters" do
      stage = projects(:test).stages.create!(name: "SDF∂ƒß∂fsƒ.&  XXX")
      stage.permalink.must_equal "sdf-ss-fs-xxx"
    end
  end
end
