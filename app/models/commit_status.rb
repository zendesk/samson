# frozen_string_literal: true
# Used to display all warnings/failures before user actually deploys
class CommitStatus
  # See ref_status_typeahead.js for how statuses are handled
  # See https://developer.github.com/v3/repos/statuses for api details
  # - fatal is our own state that blocks deploys
  # - missing is our own state that means we could not determine the status
  STATE_PRIORITY = [:success, :pending, :missing, :failure, :error, :fatal].freeze
  UNDETERMINED = ["pending", "missing"].freeze

  def initialize(project, reference, stage: nil)
    @project = project
    @reference = reference
    @stage = stage
  end

  def state
    combined_status.fetch(:state)
  end

  def statuses
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

  def expire_cache(commit)
    Rails.cache.delete(cache_key(commit))
  end

  private

  def combined_status
    @combined_status ||= begin
      statuses = [github_status]
      statuses += [release_status, *ref_statuses].compact if @stage
      statuses[1..-1].each_with_object(statuses[0]) { |status, merged| merge(merged, status) }
    end
  end

  def merge(a, b)
    a[:state] = [a.fetch(:state), b.fetch(:state)].max_by { |state| STATE_PRIORITY.index(state.to_sym) }
    a.fetch(:statuses).concat b.fetch(:statuses)
  end

  # NOTE: reply is an api object that does not support .fetch
  def github_status
    static = @reference.match?(Build::SHA1_REGEX) || @reference.match?(Release::VERSION_REGEX)
    expires_in = ->(reply) { cache_duration(reply) }
    cache_fetch_if static, cache_key(@reference), expires_in: expires_in do
      GITHUB.combined_status(@project.repository_path, @reference).to_h
    end
  rescue Octokit::NotFound
    {
      state: "missing",
      statuses: [{
        context: "Reference", # for releases/show.html.erb
        state: "missing",
        description: "'#{@reference}' does not exist"
      }]
    }
  end

  def cache_duration(github_status)
    statuses = github_status[:statuses]
    if statuses.empty? # does not have any statuses, chances are commit is new
      5.minutes # NOTE: could fetch commit locally without pulling to check it's age
    elsif (Time.now - statuses.map { |s| s[:updated_at] }.max) > 1.hour # no new updates expected
      1.day
    elsif statuses.any? { |s| UNDETERMINED.include?(s[:state]) } # expecting update shortly
      1.minute
    else # user might re-run test or success changes into failure when new status arrives
      10.minutes
    end
  end

  def cache_key(commit)
    ['commit-status', @project.id, commit]
  end

  def cache_fetch_if(condition, key, expires_in:)
    return yield unless condition

    old = Rails.cache.read(key)
    return old if old

    current = yield
    Rails.cache.write(key, current, expires_in: expires_in.call(current))
    current
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

  def ref_statuses
    statuses = []
    # Check if ref has been deployed to any non-production stages first if deploying to production
    if @stage.production? && !@stage.project.deployed_reference_to_non_production_stage?(@reference)
      statuses << {
        state: "pending",
        statuses: [{
          state: "Production Only Reference",
          description: "#{@reference} has not been deployed to a non-production stage."
        }]
      }
    end
    statuses + Samson::Hooks.fire(:ref_status, @stage, @reference).compact
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
