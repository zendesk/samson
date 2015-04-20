require 'octokit'

class Integrations::TddiumController < Integrations::BaseController
  protected

  def deploy?
    params[:status] == 'passed' &&
      params[:event] == 'stop' &&
      !skip?
  end

  def skip?
    # Tddium doesn't send commit message, so we have to get creative
    repo_name = "#{params[:repository][:org_name]}/#{params[:repository][:name]}"
    data = GITHUB.commit(repo_name, params[:commit_id])

    contains_skip_token?(data.commit.message)

  rescue Octokit::Error => e
    Rails.logger.info("Error trying to grab commit: #{e.message}")
    # We'll assume that if we don't hear back, don't skip
    false
  end

  def branch
    params[:branch]
  end

  def commit
    params[:commit_id]
  end
end
