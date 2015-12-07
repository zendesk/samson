require 'kubeclient'

class KubernetesDashboardController < ApplicationController
  include CurrentProject

  def index
    render json: format_pod_info(get_pod_info).to_json
  end

  private

  def get_pod_info
    roles = hash_with(&default_role)
    Environment.find(params[:environment]).cluster_deploy_groups.each do |cluster_deploy_group|
      cluster_deploy_group.cluster.client.get_pods(
          namespace: cluster_deploy_group.namespace,
          label_selector: "project=#{current_project.name_for_label}").each do |pod|
        labels = pod.metadata.labels
        release = roles[labels.role_id][:deploy_groups]\
                      [cluster_deploy_group.id][:releases][labels.release_id]
        api_pod = Kubernetes::Api::Pod.new(pod)
        release[:live_replicas] += 1 if api_pod.ready?
      end
    end
    roles
  end

  def hash_with(*optional_params)
    Hash.new { |hash, key| hash[key] = yield(key, *optional_params) }
  end

  def default_role
    lambda { |role_id| { name: get_role_name(role_id),
                         deploy_groups: hash_with(role_id, &default_deploy_group) } }
  end

  def default_deploy_group
    lambda { |deploy_group_id, role_id| { name: get_deploy_group_name(deploy_group_id),
                                          releases: hash_with(role_id, &default_release) } }
  end

  def default_release
    lambda { |release_id, role_id| { id: release_id, build: get_build_label(release_id),
                                     target_replicas: get_target_replicas(release_id, role_id),
                                     live_replicas: 0 } }
  end

  def get_role_name(role_id)
    Kubernetes::Role.find(role_id).name
  end

  def get_deploy_group_name(deploy_group_id)
    Kubernetes::ClusterDeployGroup.find(deploy_group_id).deploy_group.name
  end

  def get_target_replicas(release_id, role_id)
    Kubernetes::ReleaseDoc.find_by(kubernetes_release_id: release_id,
                                   kubernetes_role_id: role_id).replica_target
  end

  def get_build_label(release_id)
    Kubernetes::Release.find(release_id).build.label
  end

  # convert roles, deploy groups and releases hashes to lists
  def format_pod_info(pod_info)
    pod_info.values.each do |role|
      role[:deploy_groups].values.each do |deploy_group|
        deploy_group[:releases] = deploy_group[:releases].values
      end
      role[:deploy_groups] = role[:deploy_groups].values
    end
  end
end
