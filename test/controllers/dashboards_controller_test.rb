require_relative '../test_helper'

describe DashboardsController do
  let(:production) { environments(:production_env) }

  as_a_viewer do
    describe '#show' do
      let(:deploy) { deploys(:succeeded_production_test) }

      before { Project.any_instance.stubs(:valid_repository_url).returns(true) }

      it 'renders show' do
        get :show, id: production
        assert_response :success
        assert_template :show, partial: '_project'
        assert_select('tbody tr').count.must_equal Project.count
        assert_select('thead th').count.must_equal DeployGroup.count
        response.body.must_include ">#{deploy.reference}<"
      end

      it 'renders a custom timestamp' do
        time = deploy.updated_at - 1.day
        old = Deploy.create!(
          stage: stages(:test_production),
          job: deploy.job,
          reference: "new",
          updated_at: time - 1.day
        )
        get :show, id: production.to_param, before: time.to_s(:db)
        response.body.wont_include ">#{deploy.reference}<"
        response.body.must_include ">#{old.reference}<"
      end

      it 'renders starred projects first' do
        new_project1 = Project.create!(name: 'z1', repository_url: 'z1')
        new_project2 = Project.create!(name: 'z2', repository_url: 'z2')
        users(:viewer).stars.create!(project: new_project1)
        users(:deployer).stars.create!(project: new_project2)

        get :show, id: production
        assert_response :success
        assigns(:deploys).keys.map(&:name).must_equal ['z1', 'Project', 'z2']
      end
    end
  end
end
