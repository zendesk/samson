require 'test_helper'

describe DashboardsController do
  let(:production) { environments(:production_env) }

  def self.it_renders_show
    it 'renders show' do
      get :show, id: production
      assert_response :success
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

    as_a_admin do
      before { Project.any_instance.stubs(:valid_repository_url).returns(true) }

      it 'renders starred projects first' do
        new_project1 = Project.create!(name: 'z1', repository_url: 'z1')
        new_project2 = Project.create!(name: 'z2', repository_url: 'z2')
        users(:admin).stars.create!(project: new_project1)
        users(:deployer).stars.create!(project: new_project2)

        get :show, id: production
        assert_response :success
        assigns(:deploys).keys.map(&:name).must_equal ['z1', 'Project', 'z2']
      end
    end
  end
end
