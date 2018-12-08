# frozen_string_literal: true
class GcloudController < ApplicationController
  class GcloudCommandError < StandardError; end

  STATUSMAP = {
    "SUCCESS" => "succeeded",
    "QUEUED" => "pending",
    "WORKING" => "running",
    "FAILURE" => "failed",
    "ERRORED" => "failed",
    "TIMEOUT" => "failed",
    "CANCELLED" => "cancelled"
  }.freeze

  def sync_build
    build = Build.find(params[:id])
    path = [build.project, build]

    if (error = update_build(build))
      redirect_to path, alert: "Failed to sync: #{e}"
    else
      redirect_to path, notice: "Synced!"
    end
  end

  private

  def update_build(build)
    command = [
      "gcloud", "container", "builds", "describe", build.gcr_id, "--format", "json", *SamsonGcloud.cli_options
    ]
    success, output = Samson::CommandExecutor.execute(*command, timeout: 30, whitelist_env: ["PATH"])
    return "Failed to execute gcloud command: #{output}" unless success

    response = JSON.parse(output)
    build.external_status = STATUSMAP.fetch(response.fetch("status"))

    if build.external_status == "succeeded"
      response.dig_fetch("results", "images").each do |image|
        name = image.fetch("name").split(":", 2).first
        if name.end_with?("/#{build.image_name}")
          digest = image.fetch("digest")
          build.docker_repo_digest = "#{name}@#{digest}"
          break
        end
      end
    end

    return "Failed to save build #{build.errors.full_messages}" unless build.save
    nil
  end
end
