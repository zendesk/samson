# frozen_string_literal: true
require_relative '../test_helper'

SingleCov.covered!

describe ReferencesController do
  as_a :viewer do
    unauthorized :get, :index, project_id: :foo
  end

  as_a :project_deployer do
    describe '#index' do
      let(:project) { projects(:test) }

      include GitRepoTestHelper
      with_project_on_remote_repo

      it 'shows git references for the project' do
        get :index, params: {project_id: project.to_param, format: :json}
        response.media_type.must_equal 'application/json'
        JSON.parse(response.body).must_equal ["master"]
      end

      it 'sorts tags/branches by length and shows new tags first' do
        execute_on_remote_repo "git tag v2"
        execute_on_remote_repo "git tag v1"
        execute_on_remote_repo "git checkout -b foo"
        execute_on_remote_repo "git checkout -b baz"
        execute_on_remote_repo "git checkout -b bar"
        get :index, params: {project_id: project.to_param, format: :json}
        JSON.parse(response.body).must_equal ["v2", "v1", "foo", "baz", "bar", "master"]
      end
    end
  end
end
