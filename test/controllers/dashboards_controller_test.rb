# frozen_string_literal: true
require_relative '../test_helper'

SingleCov.covered!

describe DashboardsController do
  let(:production) { environments(:production) }

  as_a_viewer do
    describe '#show' do
      before { Project.any_instance.stubs(:valid_repository_url).returns(true) }

      it 'renders show' do
        get :show, params: {id: production}
        assert_response :success
        assert_template :show
      end

      it 'gets list of deploy groups' do
        get :deploy_groups, params: {id: production}
        JSON.parse(response.body)['deploy_groups'].map { |d| d['id'] }.sort.must_equal production.deploy_group_ids.sort
      end

      it 'renders a super old timestamp' do
        get :show, params: {id: production.to_param, before: Time.at(0).to_s(:db)}
        assert_response :success
      end
    end
  end
end
