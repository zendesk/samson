class GithubNotification
  cattr_accessor(:token) { ENV['GITHUB_TOKEN'] }

  def initialize(stage, deploy)
    @stage, @deploy = stage, deploy
  end

  def deliver
    Rails.logger.info "Updating Github PR..."

    pull_requests = @deploy.changeset.pull_requests

    if pull_requests.any?
      in_multiple_threads(pull_requests) do |pull_request|

        pull_id = pull_request.number
        status = github.add_comment(@deploy.project.github_repo, pull_id, body)

        if status == "201"
          Rails.logger.info "Updated Github PR: #{pull_id}"
        else
          Rails.logger.info "Failed to update PR: #{pull_id}, status: #{status}"
        end
      end

    end
  end

  private

  def github
    @github ||= Octokit::Client.new(access_token: token)
  end

  def body
    if $request
      host_with_protocol = "#{$request.protocol}#{$request.host_with_port}"
      short_reference_link = "<a href='#{host_with_protocol}/projects/#{@deploy.project.to_param}/deploys/#{@deploy.id}' target='_blank'>#{@deploy.short_reference}</a>"
      "This PR was deployed to #{@stage.name}. Reference: #{short_reference_link}"
    else
      "This PR was deployed to #{@stage.name}. Reference: #{@deploy.short_reference}"
    end
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
