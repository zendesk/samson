# frozen_string_literal: true
require_relative '../test_helper'

SingleCov.covered!

describe GkeClustersController do
  with_env GCLOUD_ACCOUNT: "foo", GCLOUD_PROJECT: "bar"

  as_a :admin do
    unauthorized :get, :new
    unauthorized :post, :create
  end

  as_a :super_admin do
    describe "#new" do
      it "renders" do
        get :new
        assert_response :success
      end
    end

    describe "#create" do
      def do_create(gcp_project: 'pp', cluster_name: 'cc', zone: 'zz')
        post :create, params: {gke_cluster: {gcp_project: gcp_project, cluster_name: cluster_name, zone: zone}}
      end

      let(:expected_file) { "#{ENV["GCLOUD_GKE_CLUSTERS_FOLDER"]}/pp-cc.yml" }

      around do |test|
        Dir.mktmpdir { |dir| with_env(GCLOUD_GKE_CLUSTERS_FOLDER: "#{dir}/foo") { test.call } }
      end

      it "write config and redirects to cluster creation" do
        Samson::CommandExecutor.expects(:execute).with { |*args| args.first == "chmod" }
        Samson::CommandExecutor.expects(:execute).with(
          'gcloud', 'container', 'clusters', 'get-credentials',
          '--zone', 'zz', 'cc', '--account', 'foo', '--project', 'pp',
          timeout: 10,
          env: {'KUBECONFIG' => expected_file, "CLOUDSDK_CONTAINER_USE_CLIENT_CERTIFICATE" => "True"},
          whitelist_env: ['PATH']
        ).returns([true, "foo"])
        do_create
        assert_redirected_to(
          "/kubernetes/clusters/new?kubernetes_cluster%5Bconfig_filepath%5D=#{CGI.escape(expected_file)}"
        )
        assert flash[:notice]
        assert Dir.exist?(ENV["GCLOUD_GKE_CLUSTERS_FOLDER"])
      end

      it "shows errors when command fails" do
        Samson::CommandExecutor.expects(:execute).returns([false, "foo"])
        do_create
        assert_response :success
        flash[:alert].must_include(
          "gcloud container clusters get-credentials --zone zz cc --account foo --project pp foo"
        )
      end

      it "shows errors when file exists" do
        Dir.mkdir ENV["GCLOUD_GKE_CLUSTERS_FOLDER"]
        File.write expected_file, "hellp"
        do_create
        assert_response :success
        flash[:alert].must_equal "File #{expected_file} already exists and cannot be overwritten automatically."
      end

      it 're-renders new if invalid gke cluster is submitted' do
        do_create(gcp_project: nil)
        assert_response :unprocessable_entity
        assert_select 'h1', text: 'New GKE Cluster'
      end
    end
  end
end
