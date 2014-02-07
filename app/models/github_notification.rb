class GithubNotification

  def initialize(stage, deploy)
    @stage, @deploy = stage, deploy
    @project = @deploy.project
  end

  def deliver
    Rails.logger.info "Updating Github PR..."

    github = Octokit::Client.new(access_token: ENV['GITHUB_TOKEN'])

    pull_requests = @deploy.changeset.pull_requests

    if pull_requests.any?
      in_multiple_threads(pull_requests) do |pull_request|

        pull_id = pull_request.number
        status = github.add_comment(@project.github_repo, pull_id, body)

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
    "This PR was deployed to #{@stage.name}. Reference: #{@deploy.short_reference}"
  end

  def in_multiple_threads(data)
    threads = [10, data.size].min
    data = data.dup
    (0...threads).to_a.map do
      Thread.new do
        while slice = data.shift
          yield slice
        end
      end
    end.each(&:join)
  end

end
