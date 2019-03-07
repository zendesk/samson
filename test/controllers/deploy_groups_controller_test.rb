# frozen_string_literal: true
require_relative '../test_helper'

SingleCov.covered!

describe DeployGroupsController do
  let(:deploy_group) { deploy_groups(:pod100) }
  let(:stage) { stages(:test_staging) }
  let(:json) { JSON.parse(response.body) }

  as_a :viewer do
    describe "#index" do
      let(:json) { JSON.parse(response.body) }

      it "renders" do
        get :index
        assert_template :index
        assert_response :success
        assert_select('tbody tr').count.must_equal DeployGroup.count
      end

      it "renders json" do
        get :index, format: :json
        json.keys.must_equal ['deploy_groups']
        json['deploy_groups'].size.must_equal DeployGroup.count
      end

      it "filters by stage for json api" do
        get :index, params: {project_id: stage.project.id, id: stage.id}, format: :json
        json.keys.must_equal ['deploy_groups']
        json['deploy_groups'].size.must_equal 1
        json['deploy_groups'].first.keys.must_include "name"
      end

      it "can include kubernetes_cluster" do
        get :index, params: {includes: 'kubernetes_cluster'}, format: :json
        json.keys.must_equal ['deploy_groups', 'kubernetes_clusters']

        # can find the references
        json['deploy_groups'].first.keys.must_include "kubernetes_cluster_id"
        json['kubernetes_clusters'].first.keys.wont_include "deploy_group_id"
      end
    end

    describe "#show" do
      it 'renders html' do
        get :show, params: {id: deploy_group.id}
        assert_template :show
        assert_response :success
      end

      it 'renders json with deploys and dependent projects' do
        get :show, params: {id: deploy_group.id}, format: :json
        assert_response :success
        json.keys.must_equal ["deploy_group", "deploys", "projects"]
      end
    end

    describe "#missing_config" do
      it "renders" do
        get :missing_config, params: {id: deploy_group}
        assert_template :missing_config
        assert_response :success
      end

      it "compares secrets" do
        create_secret 'production/bar/pod2/foo'
        get :missing_config, params: {id: deploy_group, compare: deploy_groups(:pod2).permalink}
        assert_template :missing_config
        assert_response :success
        assigns(:diff).must_equal(
          "bar" => {"Secrets" => ["production/bar/pod2/foo"]}
        )
      end

      it "compares environment" do
        var = EnvironmentVariable.create!(scope: deploy_groups(:pod2), parent: stage.project, name: "Foo", value: "bar")
        group = EnvironmentVariableGroup.create!(name: "G1")
        var2 = EnvironmentVariable.create!(scope: deploy_groups(:pod2), parent: group, name: "Bar", value: "baz")
        get :missing_config, params: {id: deploy_group, compare: deploy_groups(:pod2).permalink}
        assert_template :missing_config
        assert_response :success
        assigns(:diff).must_equal(
          "foo" => {"Environment" => [var]},
          "global" => {"Environment" => [var2]}
        )
      end
    end
  end

  as_a :project_admin do
    unauthorized :post, :create
    unauthorized :get, :new
    unauthorized :get, :edit, id: 1
    unauthorized :post, :update, id: 1
    unauthorized :delete, :destroy, id: 1
  end

  as_a :super_admin do
    describe "#new" do
      it 'renders' do
        get :new
        assert_response :success
      end
    end

    describe '#create' do
      it 'creates a deploy group' do
        assert_difference 'DeployGroup.count', +1 do
          post :create, params: {deploy_group: {name: 'Pod666', environment_id: environments(:staging).id}}
          assert_redirected_to deploy_group_path('pod666')
        end
      end

      it 'fails with blank name' do
        deploy_group_count = DeployGroup.count
        post :create, params: {deploy_group: {name: nil}}
        assert_template :edit
        DeployGroup.count.must_equal deploy_group_count
      end
    end

    describe '#edit' do
      it "renders" do
        get :edit, params: {id: deploy_group}
        assert_template :edit
      end
    end

    describe '#update' do
      before { request.env["HTTP_REFERER"] = deploy_groups_url }

      it 'saves' do
        post :update, params: {
          deploy_group: {
            name: 'Test Update', environment_id: environments(:production).id, permalink: 'fooo'
          },
          id: deploy_group.id
        }
        assert_redirected_to deploy_group_path('fooo')
        deploy_group.reload
        deploy_group.name.must_equal 'Test Update'
        deploy_group.permalink.must_equal 'fooo'
      end

      it 'fail to update with blank name' do
        post :update, params: {deploy_group: {name: ''}, id: deploy_group}
        assert_template :edit
        deploy_group.reload.name.must_equal 'Pod 100'
      end
    end

    describe '#destroy' do
      it 'succeeds' do
        DeployGroupsStage.delete_all
        delete :destroy, params: {id: deploy_group}
        assert_redirected_to deploy_groups_path
        DeployGroup.where(id: deploy_group.id).must_equal []
      end

      it 'fails for used deploy_group and sends user to a page that shows which groups are used+errors' do
        delete :destroy, params: {id: deploy_group}
        assert_redirected_to deploy_group
        assert flash[:alert]
        deploy_group.reload
      end
    end
  end
end
