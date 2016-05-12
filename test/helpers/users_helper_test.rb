require_relative '../test_helper'

SingleCov.covered!

describe UsersHelper do
  let(:project) { projects(:test) }

  describe "#user_project_role_radio" do
    it "allows upgrade for unchecked" do
      result = user_project_role_radio users(:viewer), project, 'Foo', Role::ADMIN.id
      result.wont_include 'checked'
      result.wont_include 'global'
      result.wont_include 'disabled="disabled"'
    end

    describe "with global access" do
      it "allows to re-check current" do
        result = user_project_role_radio users(:admin), project, 'Foo', Role::ADMIN.id
        result.must_include 'checked'
        result.must_include 'global'
        result.wont_include 'disabled="disabled"'
      end

      it "blocks downgrades" do
        result = user_project_role_radio users(:admin), project, 'Foo', Role::DEPLOYER.id
        result.must_include 'checked'
        result.must_include 'global'
        result.must_include 'disabled="disabled"'
      end

      it "allows upgrades upgrades" do
        result = user_project_role_radio users(:deployer), project, 'Foo', Role::ADMIN.id
        result.wont_include 'checked'
        result.wont_include 'global'
        result.wont_include 'disabled="disabled"'
      end
    end

    describe 'with project access' do
      it "allows to re-check current" do
        result = user_project_role_radio users(:project_admin), project, 'Foo', Role::ADMIN.id
        result.must_include 'checked'
        result.wont_include 'global'
        result.wont_include 'disabled="disabled"'
      end

      it "allows downgrades" do
        result = user_project_role_radio users(:project_admin), project, 'Foo', Role::DEPLOYER.id
        result.must_include 'checked'
        result.must_include 'global'
        result.wont_include 'disabled="disabled"'
      end

      it "allows upgrade" do
        result = user_project_role_radio users(:project_deployer), project, 'Foo', Role::ADMIN.id
        result.wont_include 'checked'
        result.wont_include 'global'
        result.wont_include 'disabled="disabled"'
      end
    end
  end
end
