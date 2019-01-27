# frozen_string_literal: true
require_relative '../../test_helper'

SingleCov.covered!

describe Kubernetes::ReleasesController do
  as_a :viewer do
    unauthorized :get, :index, project_id: :foo
    unauthorized :get, :show, project_id: :foo, id: 123
  end

  as_a :project_deployer do
    describe '#index' do
      it 'renders' do
        get :index, params: {project_id: :foo}
        assert_response :success
      end

      it "does not blow up when a deploy group was removed" do
        kubernetes_release_docs(:test_release_pod_1).deploy_group.update_column(:deleted_at, Time.now)
        get :index, params: {project_id: :foo}
        assert_response :success
      end
    end

    describe '#show' do
      it 'renders' do
        get :show, params: {project_id: :foo, id: kubernetes_releases(:test_release)}
        assert_response :success
      end
    end
  end
end
