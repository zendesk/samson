# frozen_string_literal: true
class GkeClustersController < ApplicationController
  before_action :authorize_super_admin!

  def new
    @gke_cluster = GkeCluster.new
  end

  def create
    @gke_cluster = GkeCluster.new(gke_cluster_params)

    if @gke_cluster.invalid?
      render :new, status: :unprocessable_entity
      return
    end

    project = @gke_cluster.gcp_project
    cluster = @gke_cluster.cluster_name
    zone = @gke_cluster.zone

    # prepare the file gcloud will write into
    folder = ENV.fetch("GCLOUD_GKE_CLUSTERS_FOLDER")
    Dir.mkdir(folder) unless Dir.exist?(folder)
    path = File.join(folder, "#{project}-#{cluster}.yml")

    if File.exist?(path)
      flash.now[:alert] = "File #{path} already exists and cannot be overwritten automatically."
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
      flash.now[:alert] = "Failed to execute (make sure container.cluster.getCredentials permissions are granted): " \
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

  private

  def gke_cluster_params
    params.require(:gke_cluster).permit(:gcp_project, :cluster_name, :zone)
  end
end
