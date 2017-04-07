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
    list = combined_status.fetch(:statuses).map(&:to_h)
    if list.empty?
      list << {
        state: 'pending',
        description:
          "No status was reported for this commit on GitHub. " \
          "See https://github.com/blog/1227-commit-status-api for details."
      }
    end
    list
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

  # need to do weird escape logic since other wise either 'foo/bar' or 'bar[].foo' do not work
  def github_status
    escaped_ref = @reference.gsub(/[^a-zA-Z\/\d_-]+/) { |v| CGI.escape(v) }
    GITHUB.combined_status(@stage.project.user_repo_part, escaped_ref).to_h
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
    return unless current_version = version(@reference)
    return unless higher_references = last_deployed_references.select { |n| version(n)&.> current_version }.presence

    # code above is hot ... so keep it optimized and re-fetch here only if something bad was found
    interfering_stage_ids = deploy_scope.where(reference: higher_references).pluck(:stage_id)
    interfering_stages = Stage.where(id: interfering_stage_ids).pluck(:name)

    {
      state: "error", # `pending` is also supported in deploys.js, but that seems even worse
      statuses: [{
        state: "Old Release",
        description:
          "#{higher_references.join(', ')} was deployed to deploy groups in this stage" \
          " by #{interfering_stages.join(", ")}"
      }]
    }
  end

  def version(reference)
    return unless plain = reference[Release::VERSION_REGEX, 1]
    Gem::Version.new(plain)
  end

  # optimized to sql instead of AR fanciness to make it go from 1s -> 0.01s on our worst case stage
  def last_deployed_references
    last_deployed = deploy_scope.pluck('max(deploys.id)')
    Deploy.reorder(nil).where(id: last_deployed).pluck('distinct reference')
  end

  def deploy_scope
    @deploy_scope ||= Deploy.reorder(nil).successful.where(stage_id: @stage.influencing_stage_ids).group(:stage_id)
  end
end
