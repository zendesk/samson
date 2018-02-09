# frozen_string_literal: true
class GkeClustersController < ApplicationController
  before_action :authorize_super_admin!

  def new
  end

  def create
    project = params.require(:gke_cluster).require(:gcp_project)
    cluster = params.require(:gke_cluster).require(:cluster_name)
    zone = params.require(:gke_cluster).require(:zone)

    # prepare the file gcloud will write into
    folder = ENV.fetch("GCLOUD_GKE_CLUSTERS_FOLDER")
    Dir.mkdir(folder) unless Dir.exist?(folder)
    path = File.join(folder, "#{project}-#{cluster}.yml")

    if File.exist?(path)
      flash.now[:error] = "File #{path} already exists and cannot be overwritten automatically."
      return render :new
    end

    # try to get credentials via CLI
    # without setting USE_CLIENT_CERTIFICATE certs are unusable
    command = [
      "gcloud", "container", "clusters", "get-credentials", "--zone", zone, cluster,
      *SamsonGcloud.cli_options(project: project)
    ]
    success, content = Samson::CommandExecutor.execute(
      *command,
      whitelist_env: ["PATH"],
      timeout: 10,
      env: {"KUBECONFIG" => path, "CLOUDSDK_CONTAINER_USE_CLIENT_CERTIFICATE" => "True"}
    )

    unless success
      flash.now[:error] = "Failed to execute (make sure container.cluster.getCredentials permissions are granted): " \
        "#{command.join(" ")} #{content}"
      return render :new
    end

    # we want to be able to use these certs form the console too (different user, same group)
    Samson::CommandExecutor.execute("chmod", "g+r", path, timeout: 1)

    # send user to create a cluster and pick a namespace
    redirect_to(
      new_kubernetes_cluster_path(kubernetes_cluster: {config_filepath: path}),
      notice: "Clustr config #{path} created!"
    )
  end
end
