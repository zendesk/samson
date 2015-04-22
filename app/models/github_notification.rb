class GithubNotification
  def initialize(deploy)
    @deploy = deploy
    @stage = @deploy.stage
    @project = @stage.project
  end

  def deliver
    Rails.logger.info "Updating Github PR..."

    pull_requests = @deploy.changeset.pull_requests

    if pull_requests.any?
      in_multiple_threads(pull_requests) do |pull_request|

        pull_id = pull_request.number
        status = GITHUB.add_comment(@project.github_repo, pull_id, body)

        if status == "201"
          Rails.logger.info "Updated Github PR: #{pull_id}"
        else
          Rails.logger.info "Failed to update PR: #{pull_id}, status: #{status}"
        end
      end

    end
  end

  private

  def body
    url = url_helpers.project_deploy_url(@project, @deploy)
    short_reference_link = "<a href='#{url}' target='_blank'>#{@deploy.short_reference}</a>"
    "This PR was deployed to #{@stage.name}. Reference: #{short_reference_link}"
  end

  def in_multiple_threads(data)
    threads = [10, data.size].min
    data = data.dup
    (0...threads).to_a.map do
      Thread.new do
        while slice = Thread.exclusive { data.shift }
          yield slice
        end
      end
    end.each(&:join)
  end

  def url_helpers
    Rails.application.routes.url_helpers
  end

end
