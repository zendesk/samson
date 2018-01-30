# frozen_string_literal: true
class GcloudController < ApplicationController
  def sync_build
    build = Build.find(params[:id])
    path = [build.project, build]

    if error = update_build(build)
      redirect_to path, alert: "Failed to sync: #{error}"
    else
      redirect_to path, notice: "Synced!"
    end
  end

  private

  def update_build(build)
    command = [
      "gcloud", *SamsonGcloud.container_in_beta, "container", "builds", "describe", build.gcr_id, "--format", "json",
      *SamsonGcloud.cli_options
    ]
    success, output = Samson::CommandExecutor.execute(*command, timeout: 10, whitelist_env: ["PATH"])
    return "Failed to execute gcloud command: #{output}" unless success

    JSON.parse(output).dig_fetch("results", "images").each do |image|
      name = image.fetch("name")
      if name.end_with?("/#{build.image_name}")
        digest = image.fetch("digest")
        build.update_attributes!(
          docker_repo_digest: "#{name}@#{digest}",
          external_status: "succeeded"
        )
        return # rubocop:disable Lint/NonLocalExitFromIterator done
      end
    end

    "Failed to find image with name #{build.image_name} in gcloud reply"
  end
end
