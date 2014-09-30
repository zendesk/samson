require_relative '../test_helper'

describe ProjectsHelper do
  describe "#star_link" do
    let(:project) { projects(:test) }
    let(:current_user) { users(:admin) }

    it "star a project" do
      current_user.stubs(:starred_project?).returns(false)
      link =  star_for_project(project)
      assert_includes link, %{href="/stars?id=#{project.to_param}"}
      assert_includes link, %{data-method="post"}
    end

    it "unstar a project" do
      current_user.stubs(:starred_project?).returns(true)
      link =  star_for_project(project)
      assert_includes link, %{href="/stars/#{project.to_param}"}
      assert_includes link, %{data-method="delete"}
    end

  end
end
