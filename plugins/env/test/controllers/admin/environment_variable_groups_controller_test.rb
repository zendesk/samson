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

  as_a_deployer do
    describe "#index" do
      it "renders" do
        get :index
        assert_response :success
      end
    end

    describe "#show" do
      it "renders" do
        get :show, id: env_group.id
        assert_response :success
      end
    end

    describe "#preview" do
      it "renders for groups" do
        get :preview, group_id: env_group.id
        assert_response :success
      end

      it "renders for projects" do
        get :preview, project_id: project.id
        assert_response :success
      end

      it "calls env with preview" do
        EnvironmentVariable.expects(:env).with(anything, anything, preview: true).times(3)
        get :preview, group_id: env_group.id
        assert_response :success
      end
    end

    it 'responds with unauthorized' do
      post :create, authenticity_token: set_form_authenticity_token
      @unauthorized.must_equal true, 'Request should get unauthorized'
    end

    it 'responds with unauthorized' do
      delete :destroy, id: 1, authenticity_token: set_form_authenticity_token
      @unauthorized.must_equal true, 'Request should get unauthorized'
    end

    it 'responds with unauthorized' do
      post :update, id: 1, authenticity_token: set_form_authenticity_token
      @unauthorized.must_equal true, 'Request should get unauthorized'
    end

    unauthorized :get, :new
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
            post :create, environment_variable_group: {
              environment_variables_attributes: {"0" => {name: "N1", value: "V1"}},
              name: "G2"
            }, authenticity_token:  set_form_authenticity_token
          end
        end
        assert_redirected_to "/admin/environment_variable_groups"
      end
    end

    describe "#update" do
      before { env_group }

      it "adds" do
        assert_difference "EnvironmentVariable.count", +1 do
          put :update, id: env_group.id, environment_variable_group: {
            name: "G2",
            comment: "COOMMMENT",
            environment_variables_attributes: {
              "0" => {name: "N1", value: "V1"}
            }
          }, authenticity_token:  set_form_authenticity_token
        end

        assert_redirected_to "/admin/environment_variable_groups"
        env_group.reload
        env_group.name.must_equal "G2"
        env_group.comment.must_equal "COOMMMENT"
      end

      it "updates" do
        variable = env_group.environment_variables.first
        refute_difference "EnvironmentVariable.count" do
          put :update, id: env_group.id, environment_variable_group: {
            environment_variables_attributes: {
              "0" => {name: "N1", value: "V2", scope_type_and_id: "DeployGroup-#{deploy_group.id}", id: variable.id}
            }
          }, authenticity_token:  set_form_authenticity_token
        end

        assert_redirected_to "/admin/environment_variable_groups"
        variable.reload.value.must_equal "V2"
        variable.reload.scope.must_equal deploy_group
      end

      it "destoys variables" do
        variable = env_group.environment_variables.first
        assert_difference "EnvironmentVariable.count", -1 do
          put :update, id: env_group.id, environment_variable_group: {
            environment_variables_attributes: {
              "0" => {name: "N1", value: "V2", id: variable.id, _destroy: true}
            }
          }, authenticity_token:  set_form_authenticity_token
        end

        assert_redirected_to "/admin/environment_variable_groups"
      end
    end

    describe "#destroy" do
      it "destroy" do
        env_group
        assert_difference "EnvironmentVariableGroup.count", -1 do
          delete :destroy, id: env_group.id, authenticity_token:  set_form_authenticity_token
        end
        assert_redirected_to "/admin/environment_variable_groups"
      end
    end
  end
end
