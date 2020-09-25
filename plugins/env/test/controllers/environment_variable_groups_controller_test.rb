# frozen_string_literal: true
require_relative "../test_helper"

SingleCov.covered!

describe EnvironmentVariableGroupsController do
  def self.it_updates
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

      assert_redirected_to "/environment_variable_groups"
      variable.reload.value.must_equal "V2"
      variable.reload.scope.must_equal deploy_group
    end
  end

  def self.it_destroys
    it "destroy" do
      env_group
      assert_difference "EnvironmentVariableGroup.count", -1 do
        delete :destroy, params: {id: env_group.id}
      end
      assert_redirected_to "/environment_variable_groups"
    end
  end

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

  let!(:other_env_group) do
    EnvironmentVariableGroup.create!(
      name: "OtherG1",
      environment_variables_attributes: {
        0 => {name: "X", value: "Y"},
        1 => {name: "Y", value: "Z", scope_type_and_id: "DeployGroup-#{deploy_group.id}"}
      }
    )
  end

  let(:other_project) do
    p = project.dup
    p.name = 'xxxxx'
    p.permalink = 'xxxxx'
    p.save!(validate: false)
    p
  end

  as_a :viewer do
    unauthorized :get, :new
    unauthorized :post, :create

    describe "#update" do
      it "is unauthorized" do
        patch :update, params: {id: env_group.id}
        assert_response :unauthorized
      end
    end

    describe "#destroy" do
      it "is unauthorized" do
        delete :destroy, params: {id: env_group.id}
        assert_response :unauthorized
      end
    end

    describe "#index" do
      it "renders" do
        get :index
        assert_response :success
      end

      it "renders json" do
        get :index, format: :json
        assert_response :success
        json_response = JSON.parse response.body
        first_group = json_response['environment_variable_groups'].first
        first_group.keys.must_include "name"
        first_group.keys.must_include "variable_names"
        first_group['name'].must_equal "G1"
        first_group['variable_names'].must_equal ["X", "Y"]
      end

      it "renders with envionment_variables if present" do
        get :index, params: {includes: "environment_variables", format: :json}
        assert_response :success
        project = JSON.parse(response.body)
        project.keys.must_include "environment_variables"
      end

      it "filters by project" do
        ProjectEnvironmentVariableGroup.create!(environment_variable_group: other_env_group, project: other_project)
        get :index, params: {project_id: other_project.id, format: :json}
        assert_response :success
        json_response = JSON.parse response.body
        first_group = json_response['environment_variable_groups'].first

        json_response['environment_variable_groups'].count.must_equal 1
        first_group.keys.must_include "name"
        first_group.keys.must_include "variable_names"
        first_group['name'].must_equal other_env_group.name
        first_group['variable_names'].must_equal ["X", "Y"]
      end
    end

    describe "#show" do
      def unauthorized_env_group
        ProjectEnvironmentVariableGroup.create!(environment_variable_group: env_group, project: other_project)
      end

      it "renders" do
        get :show, params: {id: env_group.id}
        assert_response :success
      end

      it 'disables fields if user cannot edit env group' do
        unauthorized_env_group
        get :show, params: {id: env_group.id}

        assert_response :success
        assert_select 'fieldset[disabled]', count: 2
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

      it "shows secret previews" do
        EnvironmentVariable.expects(:env).
          with(anything, anything, project_specific: nil, resolve_secrets: :preview).times(3)
        get :preview, params: {group_id: env_group.id}
        assert_response :success
      end

      it "can show secret paths" do
        EnvironmentVariable.expects(:env).
          with(anything, anything, project_specific: nil, resolve_secrets: false).times(3)
        get :preview, params: {group_id: env_group.id, preview: "false"}
        assert_response :success
      end
    end

    describe "a json GET to #preview" do
      it "succeeds" do
        get :preview, params: {group_id: env_group.id, project_id: project.id, preview: false}, format: :json
        assert_response :success
        json_response = JSON.parse response.body
        json_response['groups'].sort.must_equal [
          [".pod1", {"X" => "Y", "Y" => "Z"}],
          [".pod100", {"X" => "Y", "Y" => "Z"}],
          [".pod2", {"X" => "Y", "Y" => "Z"}]
        ]
      end

      it "only shows single deploy_group with filtering on" do
        get :preview, params: {group_id: env_group.id, project_id: project.id, deploy_group: "pod2"}, format: :json
        assert_response :success
        json_response = JSON.parse response.body
        json_response['groups'].sort.must_equal [
          [".pod2", {"X" => "Y", "Y" => "Z"}]
        ]
      end

      it "fails when deploy group is unknown" do
        assert_raises ActiveRecord::RecordNotFound do
          get :preview, params: {group_id: env_group.id, project_id: project.id, deploy_group: "pod23"}, format: :json
        end
      end

      describe "project_specific" do
        before do
          EnvironmentVariable.create!(parent: project, name: 'B', value: 'b')
          ProjectEnvironmentVariableGroup.create!(environment_variable_group: other_env_group, project: project)
        end

        it "renders only project env" do
          get :preview, params: {project_id: project.id, project_specific: true}, format: :json
          assert_response :success
          json_response = JSON.parse response.body
          json_response['groups'].sort.must_equal [
            [".pod1", {"B" => "b"}],
            [".pod100", {"B" => "b"}],
            [".pod2", {"B" => "b"}]
          ]
        end

        it "renders only groups env" do
          get :preview, params: {project_id: project.id, project_specific: false}, format: :json
          assert_response :success
          json_response = JSON.parse response.body
          json_response['groups'].sort.must_equal [
            [".pod1", {"X" => "Y"}],
            [".pod100", {"Y" => "Z", "X" => "Y"}],
            [".pod2", {"X" => "Y"}]
          ]
        end

        it "renders without project_specific" do
          get :preview, params: {project_id: project.id, project_specific: nil}, format: :json
          assert_response :success
          json_response = JSON.parse response.body
          json_response['groups'].sort.must_equal [
            [".pod1", {"B" => "b", "X" => "Y"}],
            [".pod100", {"B" => "b", "Y" => "Z", "X" => "Y"}],
            [".pod2", {"B" => "b", "X" => "Y"}]
          ]
        end
      end
    end
  end

  as_a :project_admin do
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
        assert_redirected_to "/environment_variable_groups"
      end

      it "shows errors" do
        refute_difference "EnvironmentVariable.count" do
          post :create, params: {environment_variable_group: {name: ""}}
        end
        assert_template "form"
      end
    end

    describe "#update" do
      let(:params) do
        {
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

      before { env_group }

      it "adds" do
        assert_difference "EnvironmentVariable.count", +1 do
          put :update, params: params
        end

        assert_redirected_to "/environment_variable_groups"
        env_group.reload
        env_group.name.must_equal "G2"
        env_group.comment.must_equal "COOMMMENT"
      end

      it_updates

      it "shows errors" do
        refute_difference "EnvironmentVariable.count" do
          put :update, params: {id: env_group.id, environment_variable_group: {name: ""}}
        end
        assert_template "form"
      end

      it "destroys variables" do
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

        assert_redirected_to "/environment_variable_groups"
      end

      it 'updates when the group is used by a project where the user is an admin' do
        ProjectEnvironmentVariableGroup.create!(environment_variable_group: env_group, project: project)
        assert_difference "EnvironmentVariable.count", +1 do
          put :update, params: params
        end
      end

      it "cannot update when not an admin for any used projects" do
        ProjectEnvironmentVariableGroup.create!(environment_variable_group: env_group, project: other_project)
        put :update, params: params
        assert_response :unauthorized
      end

      it "cannot update when not an admin for some used projects" do
        ProjectEnvironmentVariableGroup.create!(environment_variable_group: env_group, project: project)
        ProjectEnvironmentVariableGroup.create!(environment_variable_group: env_group, project: other_project)
        put :update, params: params
        assert_response :unauthorized
      end
    end

    describe "#destroy" do
      it_destroys

      it "cannot destroy when not an admin for all used projects" do
        ProjectEnvironmentVariableGroup.create!(environment_variable_group: env_group, project: other_project)
        delete :destroy, params: {id: env_group.id}
        assert_response :unauthorized
      end
    end
  end

  as_a :admin do
    describe "#update" do
      before { env_group }
      it_updates
    end

    describe "#destroy" do
      it_destroys
    end
  end
end
