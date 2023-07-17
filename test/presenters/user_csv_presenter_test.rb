# frozen_string_literal: true
require_relative '../test_helper'

SingleCov.covered!

describe UserCsvPresenter do
  describe ".to_csv" do
    before { users(:super_admin).soft_delete! }

    it "generates csv with default options" do
      csv_completeness_test({}, User.count + UserProjectRole.count)
    end

    it "generates csv with inherited option" do
      csv_completeness_test({inherited: true}, User.count * (1 + Project.count))
    end

    it "generates csv with specific project option" do
      csv_completeness_test({project_id: Project.first.id}, User.count)
    end

    it "generates csv with deleted option" do
      csv_completeness_test({deleted: true}, User.count + UserProjectRole.count + 1)
    end

    it "generates csv with specific user option and user is deleted" do
      csv_completeness_test({user_id: users(:super_admin).id}, 1 + Project.count)
    end

    it "accurately generates the inherited csv Report" do
      csv_accuracy_test(inherited: true)
    end

    def csv_completeness_test(options = {}, expected = {})
      meta_rows = 3
      UserCsvPresenter.to_csv(**options).split("\n").size.must_equal expected + meta_rows
      UserCsvPresenter.to_csv(**options).split("\n")[-2].split(",")[-1].to_i.must_equal expected
    end

    # on updating #csv_line this test helper may need to be updated
    # This tests the optimized logic against the non-optimized logic.
    def csv_accuracy_test(options = {})
      actual = CSV.parse(UserCsvPresenter.to_csv(**options))
      actual.shift
      actual.pop(2)
      actual.each do |csv_row|
        csv_row_user = User.find(csv_row[0])
        csv_row_user.wont_be_nil
        csv_row[1].must_equal csv_row_user.name
        if csv_row[3].blank?
          csv_row[4].must_equal "SYSTEM"
          csv_row[5].must_equal csv_row_user.role.name
        else
          csv_row_project = Project.find(csv_row[3])
          csv_row_project.wont_be_nil
          csv_row[4].must_equal csv_row_project.name
          csv_row[5].must_equal proj_role_test_helper(csv_row_user, csv_row_project)
        end
      end
    end

    def proj_role_test_helper(test_user, project)
      project_role = test_user.project_role_for(project)
      return test_user.role.name if project_role.nil?
      return Role::ADMIN.name if test_user.role_id == Role::SUPER_ADMIN.id
      test_user.role_id >= project_role.role_id ? test_user.role.name : project_role.role.name
    end
  end

  describe ".csv_line" do
    let(:user) { users(:project_deployer) }
    let(:role_id) { user_project_roles(:project_deployer).role_id }
    let(:project) { projects(:test) }

    it "returns project line" do
      UserCsvPresenter.csv_line(user, project, role_id).must_equal(
        [user.id, user.name, user.email, project.id, project.name, Role::DEPLOYER.name, nil]
      )
    end

    it "returns project line with user role when no project_role provided" do
      UserCsvPresenter.csv_line(user, project, nil).must_equal(
        [user.id, user.name, user.email, project.id, project.name, user.role.name, nil]
      )
    end

    it "returns system line with no project" do
      UserCsvPresenter.csv_line(user, nil, nil).must_equal(
        [user.id, user.name, user.email, "", "SYSTEM", Role::VIEWER.name, user.deleted_at]
      )
    end

    it "returns system line with no project and deleted user" do
      user.soft_delete!(validate: false)
      UserCsvPresenter.csv_line(user, nil, nil).must_equal(
        [user.id, user.name, user.email, "", "SYSTEM", Role::VIEWER.name, user.deleted_at]
      )
    end

    describe ".effective project role" do
      let(:user) { users(:project_deployer) }
      let(:role_id) { user_project_roles(:project_deployer).role_id }

      it "returns Admin when project deployer and system super admin" do
        user.update_attribute(:role_id, Role::SUPER_ADMIN.id)
        UserCsvPresenter.effective_project_role(user, role_id).must_equal Role::ADMIN.name
      end

      it "returns Deployer when project deployer and system viewer" do
        UserCsvPresenter.effective_project_role(user, role_id).must_equal Role::DEPLOYER.name
      end

      it "returns Viewer when no user_project_role.role_id provided" do
        UserCsvPresenter.effective_project_role(user, nil).must_equal Role::VIEWER.name
      end
    end
  end
end
