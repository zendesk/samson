# frozen_string_literal: true
require_relative '../../test_helper'

SingleCov.covered!

describe Api::DeployGroupsController do
  assert_route :get, "/api/deploy_groups", to: "api/deploy_groups#index"

  assert_route :get, "/api/projects/1/stages/2/deploy_groups", \
    to: "api/deploy_groups#index", params: {project_id: "1", id: "2"}

  oauth_setup!

  before { DeployGroup.stubs(:enabled?).returns(true) }

  it 'returns precondition_failed when deploy_groups are disabled' do
    DeployGroup.unstub(:enabled?)
    get :index, format: :json
    assert_response :precondition_failed
  end

  describe '#index' do
    before do
      get :index, format: :json
    end

    subject { JSON.parse(response.body) }

    it 'succeeds' do
      assert_response :success
    end

    it 'lists deploy_groups' do
      subject.keys.must_equal ['deploy_groups']
      subject['deploy_groups'].first.keys.sort.must_equal ["id", "kubernetes_cluster", "name"]
    end
  end

  describe '#index with project and stage' do
    before do
      get :index, params: {project_id: project.id, id: stage.id}, format: :json
    end

    let(:project) { projects(:test) }
    let(:stage) { project.stages.first }

    subject { JSON.parse(response.body) }

    it 'lists the associated deploy_groups for a project/stage' do
      subject.keys.must_equal ['deploy_groups']
      subject['deploy_groups'].first.keys.sort.must_equal ["id", "kubernetes_cluster", "name"]
    end

    it 'lists the correct deploy groups' do
      subject['deploy_groups'].map { |dg| dg['id'] }.must_equal stage.deploy_groups.map(&:id)
    end
  end
end
