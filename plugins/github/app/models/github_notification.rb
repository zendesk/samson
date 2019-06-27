# frozen_string_literal: true
class GithubNotification
  SUPPORTED_KEYS = [:stage_name, :reference].freeze
  DEFAULT_MESSAGE = "This PR was deployed to %{stage_name}. Reference: %{reference}"

  def initialize(deploy)
    @deploy = deploy
    @stage = @deploy.stage
    @project = @stage.project
  end

  def deliver
    Rails.logger.info "Updating GitHub PR..."
    return unless pull_requests = @deploy.changeset.pull_requests.presence

    in_multiple_threads(pull_requests) do |pull_request|
      pull_id = pull_request.number
      GITHUB.add_comment(@project.repository_path, pull_id, body)
      Rails.logger.info "Updated GitHub PR: #{pull_id}"
    end
  end

  private

  def body
    url = Rails.application.routes.url_helpers.project_deploy_url(@project, @deploy)
    short_reference_link = "<a href='#{url}' target='_blank'>#{@deploy.short_reference}</a>"

    message = @stage.github_pull_request_comment.presence || DEFAULT_MESSAGE

    message % {stage_name: @stage.name, reference: short_reference_link}
  end

  def in_multiple_threads(data)
    mutex = Mutex.new
    threads = [10, data.size].min
    data = data.dup
    Array.new(threads).map do
      Thread.new do
        while slice = mutex.synchronize { data.shift }
          yield slice
        end
      end
    end.each(&:join)
  end
end
