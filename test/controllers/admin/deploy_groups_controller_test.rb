require_relative '../../test_helper'

SingleCov.covered!

describe Admin::DeployGroupsController do
  let(:deploy_group) { deploy_groups(:pod100) }
  let(:stage) { stages(:test_staging) }

  as_a_deployer do
    unauthorized :get, :index
    unauthorized :get, :show, id: 1
    unauthorized :post, :create
    unauthorized :get, :new
    unauthorized :get, :edit, id: 1
    unauthorized :post, :update, id: 1
    unauthorized :delete, :destroy, id: 1
    unauthorized :get, :deploy_all, id: 1
    unauthorized :post, :deploy_all, id: 1
  end

  as_a_admin do
    describe "#index" do
      it "renders" do
        get :index
        assert_template :index
        assert_response :success
        assert_select('tbody tr').count.must_equal DeployGroup.count
      end
    end

    describe "#show" do
      it 'renders' do
        get :show, id: deploy_group.id
        assert_template :show
        assert_response :success
      end
    end

    unauthorized :post, :create
    unauthorized :get, :new
    unauthorized :get, :edit, id: 1
    unauthorized :post, :update, id: 1
    unauthorized :delete, :destroy, id: 1
    unauthorized :get, :deploy_all, id: 1
    unauthorized :post, :deploy_all, id: 1
  end

  as_a_super_admin do
    describe "#new" do
      it 'renders' do
        get :new
        assert_response :success
      end
    end

    describe '#create' do
      it 'creates a deploy group' do
        assert_difference 'DeployGroup.count', +1 do
          post :create, deploy_group: {name: 'pod666', environment_id: environments(:staging).id}
          assert_redirected_to admin_deploy_groups_path
        end
      end

      it 'fails with blank name' do
        deploy_group_count = DeployGroup.count
        post :create, deploy_group: {name: nil}
        assert_template :edit
        DeployGroup.count.must_equal deploy_group_count
      end
    end

    describe '#edit' do
      it "renders" do
        get :edit, id: deploy_group
        assert_template :edit
      end
    end

    describe '#update' do
      before { request.env["HTTP_REFERER"] = admin_deploy_groups_url }

      it 'saves' do
        post :update, deploy_group: {
          name: 'Test Update', environment_id: environments(:production).id
        }, id: deploy_group.id
        assert_redirected_to admin_deploy_groups_path
        DeployGroup.find(deploy_group.id).name.must_equal 'Test Update'
      end

      it 'fail to update with blank name' do
        post :update, deploy_group: {name: ''}, id: deploy_group
        assert_template :edit
        deploy_group.reload.name.must_equal 'Pod 100'
      end
    end

    describe '#destroy' do
      it 'succeeds' do
        delete :destroy, id: deploy_group
        assert_redirected_to admin_deploy_groups_path
        DeployGroup.where(id: deploy_group.id).must_equal []
      end

      it 'fails for non-existent deploy_group' do
        assert_raises ActiveRecord::RecordNotFound do
          delete :destroy, id: -1
        end
      end
    end

    describe "#deploy_all" do
      before do
        [stage, stages(:test_production)].each do |stage|
          stage.commands.first.update_attributes!(command: "cap $DEPLOY_GROUPS deploy")
        end
      end

      it "renders" do
        get :deploy_all, id: deploy_group
        assert_response :success
        assigns[:stages].must_equal [[stage, stage.deploys.first]]
      end

      it "ignores stages that do not have $DEPLOY_GROUPS" do
        stage.commands.first.update_attributes!(command: "cap pod1 deploy")
        get :deploy_all, id: deploy_group
        assigns[:stages].must_equal []
      end

      it "also lists stages that have not been deployed since they might be our last failed deploy" do
        Job.update_all(status: 'running')

        other_stage = stages(:test_production)
        other_stage.deploy_groups << deploy_group
        other_stage.commands.create!(command: "cap $DEPLOY_GROUPS deploy")
        other_stage.deploys.last.job.update_attribute(:status, 'succeeded')

        get :deploy_all, id: deploy_group
        assigns[:stages].must_equal [[stage, other_stage.deploys.first], [other_stage, other_stage.deploys.first]]
      end

      it "ignores stages where the whole environment never got deployed" do
        Job.update_all(status: 'running')
        get :deploy_all, id: deploy_group
        assigns[:stages].must_equal []
      end

      describe "without stages on current environment" do
        before { stage.deploy_groups.clear }

        it "ignores stages that are on different environments" do
          get :deploy_all, id: deploy_group
          assigns[:stages].must_equal []
        end

        it "shows stages that are on different environments when the environment was overwritten" do
          get :deploy_all, id: deploy_group, environment_id: environments(:production).id
          production_stage = stages(:test_production)
          assigns[:stages].must_equal [[production_stage, production_stage.deploys.first]]
        end
      end
    end

    describe "#deploy_all_now" do
      it "deploys matching stages" do
        stage.update_attributes!(name: deploy_group.name.upcase + '  ----')
        assert_no_difference "Stage.count" do
          post :deploy_all_now, id: deploy_group, stages: ["#{stage.id}-master"]
        end
        deploy = stage.deploys.order('created_at desc').first.id
        assert_redirected_to "/deploys?ids%5B%5D=#{deploy}"
      end

      describe "when it does not match" do
        before { stage.deploy_groups << deploy_groups(:pod2) }

        it "deploys to a new stage" do
          assert_difference "Stage.count", +1 do
            post :deploy_all_now, id: deploy_group, stages: ["#{stage.id}-master"]
          end
          deploy = Deploy.first
          new_stage = deploy.stage
          new_stage.wont_equal stage
          assert_redirected_to "/deploys?ids%5B%5D=#{deploy.id}"
        end

        it "deploys to a new stage when it does not match and a stage with the same name already exists" do
          stage.update_attribute(:name, deploy_group.name)
          assert_difference "Stage.count", +1 do
            post :deploy_all_now, id: deploy_group, stages: ["#{stage.id}-master"]
          end
        end
      end
    end
  end
end
