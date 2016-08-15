# frozen_string_literal: true
require_relative '../test_helper'

SingleCov.covered!

describe UserProjectRole do
  let(:user) { users(:viewer) }
  let(:project) { projects(:test) }
  let(:project_role) { UserProjectRole.create!(user_id: user.id, project_id: project.id, role_id: Role::ADMIN.id) }

  before { project_role }

  describe "creates a new project role from a hash" do
    it "is persisted" do
      project_role.persisted?.must_equal(true)
    end

    it "it created the mapping with the User and the Project" do
      project_role.user.wont_be_nil
      project_role.project.wont_be_nil
    end
  end

  describe "fails to create a project role with an invalid role" do
    let(:invalid_role) { UserProjectRole.create(user_id: user.id, project_id: project.id, role_id: 3) }

    it "is not persisted" do
      invalid_role.persisted?.must_equal(false)
    end

    it "contains errors" do
      invalid_role.errors.wont_be_empty
    end
  end

  describe "fails to create yet another project role for same user and project" do
    let(:another_role) { UserProjectRole.create(user_id: user.id, project_id: project.id, role_id: Role::DEPLOYER.id) }

    it "is not persisted" do
      another_role.persisted?.must_equal(false)
    end

    it "contains errors" do
      another_role.errors.wont_be_empty
    end
  end

  describe "updates an existing project role" do
    before do
      project_role.update(role_id: Role::DEPLOYER.id)
    end

    it "does not update the user" do
      project_role.user.must_equal user
    end

    it "does not update the project" do
      project_role.project.must_equal project
    end

    it "updated the role" do
      project_role.role_id.must_equal Role::DEPLOYER.id
    end
  end

  describe "fails to update a project role with an invalid role" do
    before do
      project_role.update(role_id: 3)
    end

    it "is persisted" do
      project_role.persisted?.must_equal(true)
    end

    it "contains errors" do
      project_role.errors.wont_be_empty
    end
  end

  describe "versioning" do
    around { |t| PaperTrail.with_logging(&t) }

    it "tracks important changes" do
      project_role.versions.size.must_equal 1
      project_role.update_attributes!(role_id: 1)
      project_role.versions.size.must_equal 2
    end

    it "ignores unimportant changes" do
      project_role.update_attributes!(updated_at: 1.second.from_now)
      project_role.versions.size.must_equal 1
    end
  end
end
