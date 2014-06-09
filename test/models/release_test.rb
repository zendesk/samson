require_relative '../test_helper'

describe Release do

  let(:project) { projects(:test) }
  let(:author) { users(:admin) }

  describe "validations" do

    it "validates uniqueness of version scoped to the project" do
      Release.create!(project: project, author: author, commit: "foo", version: "v2345")
      release = Release.new(project: project, author: author, commit: "foo", version: "v2345")

      assert_equal release.invalid?(:version), true
    end
  end

end
