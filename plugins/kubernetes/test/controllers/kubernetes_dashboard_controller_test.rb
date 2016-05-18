# rubocop:disable Metrics/LineLength
require_relative '../test_helper'

SingleCov.covered!

describe KubernetesDashboardController do
  let(:project) { projects(:test) }
  let(:environment) { environments(:production) }
  let(:release) { kubernetes_releases(:test_release) }

  as_a_viewer do
    before do
      Kubernetes::Cluster.any_instance.stubs(:client).returns(Kubeclient::Client.new('http://cluster.localhost'))
    end

    it 'returns an empty array if no pods are running' do
      environment.cluster_deploy_groups.each do |cluster_deploy_group|
        stub_request(:get, %r{http://cluster\.localhost.*/namespaces/#{cluster_deploy_group.namespace}.*}).
          to_return(body: '{}')
      end

      get :index, project_id: :foo, environment: environment.id, format: :json
      assert_response :success
      response.body.must_equal '[]'
    end

    it 'returns a properly formatted response' do
      environment.cluster_deploy_groups.each do |cluster_deploy_group|
        stub_request(:get, %r{http://cluster\.localhost.*/namespaces/#{cluster_deploy_group.namespace}.*}).
          to_return(body: pod_list(cluster_deploy_group).to_json)
      end

      get :index, project_id: project.id, environment: environment.id, format: :json

      assert_response :success
      compare_json(expected_response.to_json, response.body)
    end

    it 'passes correct params to client' do
      environment.cluster_deploy_groups.each do |cluster_deploy_group|
        Kubeclient::Client.any_instance.expects(:get_pods).with(
          namespace: cluster_deploy_group.namespace,
          label_selector: "project_id=#{project.id}"
        ).returns([])
      end

      get :index, project_id: :foo, environment: environment.id, format: :json
      assert_response :success
      response.body.must_equal '[]'
    end
  end

  private

  def compare_json(expected, actual)
    expected_json = JSON.parse(expected)
    actual_json = JSON.parse(actual)
    actual_json.must_equal expected_json
  end

  def pod_list(cluster_deploy_group)
    empty_list_template.tap do |list|
      release.release_docs.each do |release_doc|
        list.items << pod_item(cluster_deploy_group, release_doc) if release_doc.deploy_group == cluster_deploy_group.deploy_group
      end
    end
  end

  def pod_item(cluster_deploy_group, release_doc)
    pod_list_item(release_doc.kubernetes_release.project, release_doc.kubernetes_release, release_doc.kubernetes_role, cluster_deploy_group)
  end

  def empty_list_template
    RecursiveOpenStruct.new(
      kind: 'PodList',
      apiVersion: 'v1',
      items: []
    )
  end

  def pod_list_item(project, release, role, cluster_deploy_group)
    {
      metadata: {
        name: 'pod-name',
        namespace: cluster_deploy_group.namespace,
        labels: {
          project_id: project.id,
          release_id: release.id,
          deploy_group_id: cluster_deploy_group.deploy_group.id,
          role_id: role.id
        }
      },
      status: {
        phase: 'Running',
        conditions: [
          {
            type: 'Ready',
            status: 'True'
          }
        ]
      }
    }
  end

  def expected_response
    [].tap do |response|
      release.release_docs.each do |release_doc|
        add_role(response, release_doc).tap do |role|
          add_deploy_group(role, release_doc).tap do |deploy_group|
            add_release(deploy_group, release_doc)
          end
        end
      end
    end
  end

  def add_role(response, release_doc)
    response << role_template(release_doc.kubernetes_role) unless response.any? do |role|
      role.id == release_doc.kubernetes_role.id
    end

    response.find { |role| role.id == release_doc.kubernetes_role.id }
  end

  def add_deploy_group(role, release_doc)
    role.deploy_groups << deploy_group_template(release_doc.deploy_group) unless role.deploy_groups.any? do |deploy_group|
      deploy_group.id == release_doc.deploy_group.id
    end

    role.deploy_groups.find { |deploy_group| deploy_group.id == release_doc.deploy_group.id }
  end

  def add_release(deploy_group, release_doc)
    deploy_group.releases << release_template(release, release_doc) unless deploy_group.releases.any? do |release|
      release.id == release_doc.kubernetes_release.id
    end
  end

  def role_template(role)
    RecursiveOpenStruct.new(
      id: role.id,
      name: role.name,
      deploy_groups: []
    )
  end

  def deploy_group_template(deploy_group)
    RecursiveOpenStruct.new(
      id: deploy_group.id,
      name: deploy_group.name,
      releases: []
    )
  end

  def release_template(release, release_doc)
    RecursiveOpenStruct.new(
      id: release.id,
      build: release.build.label,
      target_replicas: release_doc.replica_target,
      live_replicas: 1,
      failed: false
    )
  end
end
