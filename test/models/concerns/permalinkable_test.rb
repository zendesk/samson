require_relative '../../test_helper'

describe Permalinkable, :model do

  before(:all) do
    Project.any_instance.stubs(:setup_repository).returns(true)
  end

  let(:project) { projects(:test) }
  let(:project_url) { "git://foo.com:hello/world.git" }
  let(:other_project) { Project.create!(name: "hello", repository_url: project_url) }

  describe "#to_param" do
    it "is permalink" do
      project.to_param.must_equal "foo"
    end
  end

  describe "#generate_permalink" do
    it "generates a unique link" do
      project = Project.create!(name: "hello", repository_url: project_url)
      project.permalink.must_equal "world"
    end

    it "generates with id when not unique" do
      Project.create!(name: "hello", repository_url: project_url)
      project = Project.create!(name: "hello", repository_url: project_url)
      project.permalink.must_match /\Aworld-[a-f\d]+\Z/
    end

    it "generates without id when unique in scope" do
      other_project.stages.create!(name: "hello")

      stage = project.stages.create!(name: "hello")
      stage.permalink.must_equal "hello"
    end

    it "removes invalid url characters" do
      stage = project.stages.create!(name: "SDF∂ƒß∂fsƒ.&  XXX")
      stage.permalink.must_equal "sdf-ss-fs-xxx"
    end
  end

  describe ".find_by_param!" do
    it "finds" do
      Project.find_by_param!("foo").must_equal project
    end

    it "behaves like find when not finding" do
      assert_raise ActiveRecord::RecordNotFound do
        Project.find_by_param!("bar")
      end
    end

    it "finds based on scope" do
      stage = stages(:test_staging)
      other_stage = other_project.stages.create!(name: stage.name)
      other_stage.permalink.must_equal stage.permalink
      other_project.stages.find_by_permalink!(stage.permalink).must_equal other_stage
    end
  end
end
