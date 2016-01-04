require 'kubeclient'

class KubernetesDashboardController < ApplicationController
  include CurrentProject

  def index
    render json: format_pod_info(pod_info).to_json
  end

  private

  def pod_info
    roles = {}
    Environment.find(params[:environment]).cluster_deploy_groups.each do |cluster_deploy_group|
      cluster_deploy_group.cluster.client.get_pods(
          namespace: cluster_deploy_group.namespace,
          label_selector: "project=#{current_project.name_for_label}").each do |pod|
        build_pod_info(roles, cluster_deploy_group.deploy_group.id, pod)
      end
    end
    roles
  end

  def build_pod_info(roles, deploy_group_id, pod)
    labels = pod.metadata.labels

    role = role(roles, labels.role_id)
    deploy_group = deploy_group(role[:deploy_groups], deploy_group_id)
    release = release(deploy_group[:releases], labels.release_id, labels.role_id)

    api_pod = Kubernetes::Api::Pod.new(pod)
    release[:live_replicas] += 1 if api_pod.ready?
  end

  def role(roles, role_id)
    roles[role_id] ||= build_role(role_id)
  end

  def build_role(role_id)
    {
        id: role_id,
        name: role_name(role_id),
        deploy_groups: {}
    }
  end

  def deploy_group(deploy_groups, deploy_group_id)
    deploy_groups[deploy_group_id] ||= build_deploy_group(deploy_group_id)
  end

  def build_deploy_group(deploy_group_id)
    {
        name: deploy_group_name(deploy_group_id),
        releases: {}
    }
  end

  def release(releases, release_id, role_id)
    releases[release_id] ||= build_release(release_id, role_id)
  end

  def build_release(release_id, role_id)
    {
        id: release_id,
        build: build_label(release_id),
        target_replicas: target_replicas(release_id, role_id),
        live_replicas: 0
    }
  end

  def role_name(role_id)
    Kubernetes::Role.find(role_id).name
  end

  def deploy_group_name(deploy_group_id)
    DeployGroup.find(deploy_group_id).name
  end

  def target_replicas(release_id, role_id)
    Kubernetes::ReleaseDoc.find_by(kubernetes_release_id: release_id,
                                   kubernetes_role_id: role_id).replica_target
  end

  def build_label(release_id)
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
