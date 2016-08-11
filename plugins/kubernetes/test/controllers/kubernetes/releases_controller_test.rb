# frozen_string_literal: true
require_relative '../../test_helper'

SingleCov.covered!

describe Kubernetes::ReleasesController do
  as_a_viewer do
    unauthorized :get, :index, project_id: :foo
  end

  as_a_project_deployer do
    describe 'a GET to #index' do
      it 'renders' do
        get :index, project_id: :foo
        assert_response :success
      end
    end
  end
end
