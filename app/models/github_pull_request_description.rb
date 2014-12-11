class GithubPullRequestDescription
  def initialize(stage, deploy)
    @stage, @deploy = stage, deploy
    @project = @stage.project
  end

  def update_deploy_status
    Rails.logger.info "Updating pull request description..."

    pull_requests = @deploy.changeset.pull_requests

    #if pull_requests.any?
      #in_multiple_threads(pull_requests) do |pull_request|

      pull_requests.each do |pull_request|
        pull_id = pull_request.number

        new_body = pr_body_without_deploy_message(pull_id) + new_status
        status = GITHUB.update_pull_request(repo, pull_id, body: new_body)

        if status == "200"
          Rails.logger.info "Updated Github PR: #{pull_id}"
        else
          Rails.logger.info "Failed to update PR: #{pull_id}, status: #{status}"
        end
      end

    #end
  end

  private

  def repo
    @project.github_repo
  end

  def pr_body_without_deploy_message(pull_id)
    pull_request = GITHUB.pull_request(repo, pull_id)

    pull_request.body.partition(/\n\n##### Samson is deploying/).first
  end

  def new_status
    <<-STATUS.strip_heredoc

      ##### Samson is deploying #{@deploy.short_reference}

      #{deploy_statuses}
    STATUS
  end

  def deploy_statuses
    @project.stages.map do |stage|
      deploy = stage.deploys.where(reference: @deploy.reference).last

      "- #{stage.name} #{deploy_status_mark(deploy)}"
    end.join("\n")
  end

  def deploy_status_mark(deploy)
    case deploy.status
    when 'succeeded'
      ':heavy_check_mark:'
    when 'running'
      ':arrows_clockwise:'
    else 'failed'
      ':heavy_multiplication_x:'
    end
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
end
