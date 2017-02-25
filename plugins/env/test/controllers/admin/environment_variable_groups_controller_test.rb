# frozen_string_literal: true
require_relative "../../test_helper"

SingleCov.covered!

describe Admin::EnvironmentVariableGroupsController do
  let(:stage) { stages(:test_staging) }
  let(:project) { stage.project }
  let(:deploy_group) { stage.deploy_groups.first }
  let!(:env_group) do
    EnvironmentVariableGroup.create!(
      name: "G1",
      environment_variables_attributes: {
        0 => {name: "X", value: "Y"},
        1 => {name: "Y", value: "Z"}
      }
    )
  end

  as_a_viewer do
    unauthorized :get, :new
    unauthorized :post, :create
    unauthorized :patch, :update, id: 1
    unauthorized :delete, :destroy, id: 1

    describe "#index" do
      it "renders" do
        get :index
        assert_response :success
      end
    end

    describe "#show" do
      it "renders" do
        get :show, params: {id: env_group.id}
        assert_response :success
      end
    end

    describe "#preview" do
      it "renders for groups" do
        get :preview, params: {group_id: env_group.id}
        assert_response :success
      end

      it "renders for projects" do
        get :preview, params: {project_id: project.id}
        assert_response :success
      end

      it "calls env with preview" do
        EnvironmentVariable.expects(:env).with(anything, anything, preview: true).times(3)
        get :preview, params: {group_id: env_group.id}
        assert_response :success
      end
    end
  end

  as_a_admin do
    describe "#new" do
      it "renders" do
        get :new
        assert_response :success
      end
    end

    describe "#create" do
      it "creates" do
        assert_difference "EnvironmentVariable.count", +1 do
          assert_difference "EnvironmentVariableGroup.count", +1 do
            post :create, params: {
              environment_variable_group: {
                environment_variables_attributes: {"0" => {name: "N1", value: "V1"}},
                name: "G2"
              }
            }
          end
        end
        assert_redirected_to "/admin/environment_variable_groups"
      end
    end

    describe "#update" do
      before { env_group }

      it "adds" do
        assert_difference "EnvironmentVariable.count", +1 do
          put :update, params: {
            id: env_group.id,
            environment_variable_group: {
              name: "G2",
              comment: "COOMMMENT",
              environment_variables_attributes: {
                "0" => {name: "N1", value: "V1"}
              }
            }
          }
        end

        assert_redirected_to "/admin/environment_variable_groups"
        env_group.reload
        env_group.name.must_equal "G2"
        env_group.comment.must_equal "COOMMMENT"
      end

      it "updates" do
        variable = env_group.environment_variables.first
        refute_difference "EnvironmentVariable.count" do
          put :update, params: {
            id: env_group.id,
            environment_variable_group: {
              environment_variables_attributes: {
                "0" => {name: "N1", value: "V2", scope_type_and_id: "DeployGroup-#{deploy_group.id}", id: variable.id}
              }
            }
          }
        end

        assert_redirected_to "/admin/environment_variable_groups"
        variable.reload.value.must_equal "V2"
        variable.reload.scope.must_equal deploy_group
      end

      it "destoys variables" do
        variable = env_group.environment_variables.first
        assert_difference "EnvironmentVariable.count", -1 do
          put :update, params: {
            id: env_group.id, environment_variable_group: {
              environment_variables_attributes: {
                "0" => {name: "N1", value: "V2", id: variable.id, _destroy: true}
              }
            }
          }
        end

        assert_redirected_to "/admin/environment_variable_groups"
      end
    end

    describe "#destroy" do
      it "destroy" do
        env_group
        assert_difference "EnvironmentVariableGroup.count", -1 do
          delete :destroy, params: {id: env_group.id}
        end
        assert_redirected_to "/admin/environment_variable_groups"
      end
    end
  end
end
