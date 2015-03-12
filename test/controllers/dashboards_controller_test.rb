require_relative '../test_helper'

describe DashboardsController do
  let(:production) { environments(:production_env) }

  as_a_viewer do
    describe '#show' do
      let(:deploy) { deploys(:succeeded_production_test) }

      it 'renders show' do
        get :show, id: production.to_param
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
    end
  end
end
