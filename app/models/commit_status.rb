# frozen_string_literal: true
# Used to display all warnings/failures before user actually deploys
class CommitStatus
  STATUS_PRIORITY = {
    success: 0,
    pending: 1,
    failure: 2,
    error: 3
  }.freeze

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
    @combined_status ||= begin
      statuses = [github_status, release_status, ref_status]
      statuses.each_with_object({}) { |status, merged_statuses| merge(merged_statuses, status) }
    end
  end

  def merge(a, b)
    return a unless b
    a[:state] = pick_highest_state(a[:state], b.fetch(:state))
    (a[:statuses] ||= []).concat b.fetch(:statuses)
  end

  # picks the state with the higher priority
  def pick_highest_state(a, b)
    return b if a.nil?
    STATUS_PRIORITY[a.to_sym] > STATUS_PRIORITY[b.to_sym] ? a : b
  end

  # need to do weird escape logic since other wise either 'foo/bar' or 'bar[].foo' do not work
  def github_status
    escaped_ref = @reference.gsub(/[^a-zA-Z\/\d_-]+/) { |v| CGI.escape(v) }
    GITHUB.combined_status(@stage.project.repository_path, escaped_ref).to_h
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

  def ref_status
    # Check if ref has been deployed to any non-production stages first if deploying to production
    if @stage.production? && !@stage.project.deployed_reference_to_non_production_stage?(@reference)
      {
        state: "pending",
        statuses: [{
          state: "Production Only Reference",
          description: "#{@reference} has not been deployed to a non-production stage."
        }]
      }
    end
  end

  def version(reference)
    return unless plain = reference[Release::VERSION_REGEX, 1]
    Gem::Version.new(plain)
  end

  # optimized to sql instead of AR fanciness to make it go from 1s -> 0.01s on our worst case stage
  def last_deployed_references
    last_deployed = deploy_scope.pluck(Arel.sql('max(deploys.id)'))
    Deploy.reorder(nil).where(id: last_deployed).pluck(Arel.sql('distinct reference'))
  end

  def deploy_scope
    @deploy_scope ||= Deploy.reorder(nil).successful.where(stage_id: @stage.influencing_stage_ids).group(:stage_id)
  end
end
