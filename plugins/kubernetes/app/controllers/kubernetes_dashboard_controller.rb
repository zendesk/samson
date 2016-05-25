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
      namespace = cluster_deploy_group.namespace
      selector = "project_id=#{current_project.id}"
      cluster = cluster_deploy_group.cluster

      cluster.client.get_pods(namespace: namespace, label_selector: selector).each do |pod|
        build_pod_info(roles, cluster_deploy_group.deploy_group.id, pod)
      end
    end
    roles
  end

  def build_pod_info(roles, deploy_group_id, pod)
    labels = pod.metadata.labels
    return unless labels.role_id && labels.release_id # skip misconfigured / manually created pods

    role = role(roles, labels.role_id)
    deploy_group = deploy_group(role[:deploy_groups], deploy_group_id)
    release = release(deploy_group[:releases], labels.release_id, labels.role_id, deploy_group_id)

    api_pod = Kubernetes::Api::Pod.new(pod)
    release[:live_replicas] += 1 if api_pod.live?
  end

  def role(roles, role_id)
    roles[role_id] ||= {
      id: role_id,
      name: role_name(role_id),
      deploy_groups: {}
    }
  end

  def deploy_group(deploy_groups, deploy_group_id)
    deploy_groups[deploy_group_id] ||= {
      id: deploy_group_id,
      name: deploy_group_name(deploy_group_id),
      releases: {}
    }
  end

  def release(releases, release_id, role_id, deploy_group_id)
    release_doc = release_doc(release_id, role_id, deploy_group_id)
    releases[release_id] ||= {
      id: release_id,
      build: build_label(release_id),
      target_replicas: release_doc.replica_target,
      live_replicas: 0,
      failed: release_doc.failed?
    }
  end

  def role_name(role_id)
    Kubernetes::Role.find(role_id).name
  end

  def deploy_group_name(deploy_group_id)
    DeployGroup.find(deploy_group_id).name
  end

  def release_doc(release_id, role_id, deploy_group_id)
    Kubernetes::ReleaseDoc.find_by(
      kubernetes_release_id: release_id,
      kubernetes_role_id: role_id,
      deploy_group_id: deploy_group_id
    )
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
