require 'test_helper'

describe DashboardsController do
  let(:production) { environments(:production_env) }

  def self.it_renders_show
    it 'get :show succeeds' do
      get :show, id: production.to_param
      assert_template :show, partial: '_project'
      assert_select('tbody tr').count.must_equal Project.count
      assert_select('thead th').count.must_equal DeployGroup.count
    end
  end

  describe '#show' do
    as_a_viewer { it_renders_show }
    as_a_deployer { it_renders_show }
    as_a_admin { it_renders_show }
    as_a_super_admin { it_renders_show }
  end
end
