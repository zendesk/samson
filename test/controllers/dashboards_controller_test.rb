require_relative '../test_helper'

describe DashboardsController do
  let(:production) { environments(:production) }

  as_a_viewer do
    describe '#show' do
      before { Project.any_instance.stubs(:valid_repository_url).returns(true) }

      it 'renders show' do
        get :show, id: production
        assert_response :success
        assert_template :show
      end

      it 'gets list of deploy groups' do
        get :deploy_groups, id: production
        JSON.parse(response.body)['deploy_groups'].map { |dg| dg['id'] }.must_equal production.deploy_group_ids
      end

      it 'renders a super old timestamp' do
        get :show, id: production.to_param, before: Time.at(0).to_s(:db)
        assert_response :success
      end
    end
  end
end
