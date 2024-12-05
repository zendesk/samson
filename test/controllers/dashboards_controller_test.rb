# frozen_string_literal: true
require_relative '../test_helper'

SingleCov.covered!

describe DashboardsController do
  let(:environment) { environments(:production) }

  as_a :viewer do
    describe '#show' do
      before { Project.any_instance.stubs(:valid_repository_url).returns(true) }

      it 'renders show' do
        get :show, params: {id: environment}
        assert_response :success
        assert_template :show
      end

      it 'renders a super old timestamp' do
        get :show, params: {id: environment, before: Time.at(0).to_fs(:db)}
        assert_response :success
      end
    end

    describe "#deploy_groups" do
      it 'gets list of deploy groups' do
        get :deploy_groups, params: {id: environment}
        JSON.parse(response.body)['deploy_groups'].map { |d| d['id'] }.sort.must_equal environment.deploy_group_ids.sort
      end
    end
  end
end
