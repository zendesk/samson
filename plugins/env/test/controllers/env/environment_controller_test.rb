# frozen_string_literal: true
require_relative "../../test_helper"

SingleCov.covered!

describe Env::EnvironmentController do
  unauthorized :get, :show, project_id: 1, deploy_group: 1

  as_a :viewer do
    describe "#show" do
      let(:project) { projects(:test) }
      let(:deploy_group) { deploy_groups(:pod1) }
      let(:secret_id) { 'global/global/global/s' }

      before do
        EnvironmentVariable.create!(parent: project, name: 'A', value: 'a$C')
        EnvironmentVariable.create!(parent: projects(:other), name: 'B', value: 'b')
        EnvironmentVariable.create!(parent: project, scope: deploy_group, name: 'C', value: 'c')
        EnvironmentVariable.create!(parent: project, scope: deploy_groups(:pod2), name: 'D', value: 'd')

        create_secret secret_id
        EnvironmentVariable.create!(parent: project, name: 'S', value: 'secret://s')

        group = EnvironmentVariableGroup.create!(name: 'foo', projects: [project])
        group.environment_variables.create!(name: 'E', value: 'e')
      end

      it 'renders' do
        get :show, params: {project_id: project, deploy_group: deploy_group}
        assert_response :success

        response.body.must_equal <<~TEXT
          C="c"
          A="ac"
          S="secret://global/global/global/s"
          E="e"
        TEXT
      end

      it 'raises if project not found' do
        assert_raises ActiveRecord::RecordNotFound do
          get :show, params: {project_id: -1, deploy_group: deploy_group}
        end
      end

      it 'raises if deploy group not found' do
        assert_raises ActiveRecord::RecordNotFound do
          get :show, params: {project_id: project, deploy_group: -1}
        end
      end

      it 'gives unprocessable entity if secret is not resolved' do
        Samson::Secrets::Manager.delete(secret_id)
        get :show, params: {project_id: project, deploy_group: deploy_group}
        assert_response :unprocessable_entity
        response.body.must_include 'Unexpanded secrets found: secret://s X'
      end
    end
  end
end
