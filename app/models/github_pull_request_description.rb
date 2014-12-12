class GithubPullRequestDescription
  def initialize(stage, deploy)
    @stage, @deploy = stage, deploy
    @project = @stage.project
  end

  def update_deploy_status
    Rails.logger.info "Updating pull request description..."

    pull_requests = @deploy.changeset.pull_requests

    if pull_requests.any?
      in_multiple_threads(pull_requests) do |pull_request|

        pull_id = pull_request.number

        new_pr_body = pr_body_without_deploy_message(pull_id) + deploy_message
        status = GITHUB.update_pull_request(repo, pull_id, body: new_pr_body)

        if status == "200"
          Rails.logger.info "Updated Github PR: #{pull_id}"
        else
          Rails.logger.info "Failed to update PR: #{pull_id}, status: #{status}"
        end
      end

    end
  end

  private

  def repo
    @project.github_repo
  end

  def pr_body_without_deploy_message(pull_id)
    pull_request = GITHUB.pull_request(repo, pull_id)

    pull_request.body.partition(/---\n\n#### Samson is deploying/).first
  end

  def deploy_message
    "---\n\n#### Samson is deploying #{whats_deploying}\n#{deploy_statuses}"
  end

  def whats_deploying
    Release.find_by(commit: @deploy.reference).try(:version) ||
      @deploy.short_reference
  end

  def deploy_statuses
    deploys_on_all_stages = @project.stages.map do |stage|
      stage.deploys.where(reference: @deploy.reference).last
    end

    badges = DeploymentBadges.new(deploys_on_all_stages)

    badges.to_s
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

  class DeploymentBadges
    def initialize(deploys = [])
      @deploys = deploys
    end

    def to_s
      badges.map(&:to_markdown).join(" ")
    end

    def badges
      success_badge = SuccessBadge.new
      running_badge = RunningBadge.new
      failure_badge = FailureBadge.new

      deploys.each do |deploy|
        if deploy.succeeded?
          success_badge << deploy.stage
        elsif deploy.running?
          running_badge << deploy.stage
        elsif deploy.failed? || deploy.errored?
          failure_badge << deploy.stage
        end
      end

      [success_badge, running_badge, failure_badge].reject(&:empty?)
    end

    private

    attr_reader :deploys

    class Badge
      def initialize
        @stages = []
      end

      def <<(stage)
        @stages << stage
      end

      def empty?
        stages.none?
      end

      def to_markdown
        "![](http://img.shields.io/badge/#{title}-#{stage_names.join(', ')}-#{color}.svg?style-flat)"
      end

      private

      attr_reader :stages

      def stage_names
        stages.map(&:name).sort
      end
    end

    class SuccessBadge < Badge
      def title ; "Deployed" ; end
      def color ; "green"    ; end
    end

    class RunningBadge < Badge
      def title ; "Running" ; end
      def color ; "yellow"  ; end
    end

    class FailureBadge < Badge
      def title ; "Failed" ; end
      def color ; "red"    ; end
    end
  end
end
