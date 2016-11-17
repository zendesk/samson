# frozen_string_literal: true
# Used to display all warnings/failures before user actually deploys
class CommitStatus
  def initialize(stage, reference)
    @stage = stage
    @reference = reference
  end

  def status
    combined_status.fetch(:state)
  end

  def status_list
    combined_status.fetch(:statuses).map(&:to_h)
  end

  private

  def combined_status
    @combined_status ||= merge(github_status, release_status)
  end

  # simplistic merge that overrides state and combines messages
  def merge(a, b)
    return a unless b
    a[:state] = b.fetch(:state)
    (a[:statuses] ||= []).concat b.fetch(:statuses)
    a
  end

  def github_status
    GITHUB.combined_status(@stage.project.user_repo_part, @reference).to_h
  rescue Octokit::NotFound
    {
      state: "failure",
      statuses: [{"state": "Reference", description: "'#{@reference}' does not exist"}]
    }
  end

  # checks if other stages that deploy to the same hosts as this stage have deployed a newer release
  # @return [nil, error-state]
  def release_status
    return unless DeployGroup.enabled?
    return unless number = @reference[Release::VERSION_REGEX, 1]

    deploy_groups = @stage.deploy_groups.pluck(:deploy_group_id)
    influencing_stages = DeployGroupsStage.where(deploy_group_id: deploy_groups).map(&:stage).uniq
    last_deploys = influencing_stages.map(&:last_successful_deploy).compact # N+1 ... cannot order and then group
    last_deployed_numbers = last_deploys.map(&:reference).map { |r| r[Release::VERSION_REGEX, 1] }.compact

    highest = ([number] + last_deployed_numbers).max_by { |n| Gem::Version.new(n) }
    return if number == highest

    {
      state: "error", # `pending` is also supported in deploys.js, but that seems even worse
      statuses: [{
        state: "Old Release", description: "v#{highest} was already deployed to hosts in this stage"
      }]
    }
  end
end
