# frozen_string_literal: true
# Used to display all warnings/failures before user actually deploys
class CommitStatus
  # See ref_status_typeahead.js for how statuses are handled
  # See https://developer.github.com/v3/repos/statuses for api details
  # - fatal is our own state that blocks deploys
  # - missing is our own state that means we could not determine the status
  STATE_PRIORITY = [:success, :pending, :missing, :failure, :error, :fatal].freeze
  UNDETERMINED = ["pending", "missing"].freeze
  CHECK_STATE = {
    error: ['action_required', 'cancelled', 'timed_out', 'stale', 'startup_failure'],
    failure: ['failure'],
    success: ['success', 'neutral', 'skipped']
  }.freeze
  NO_STATUSES_REPORTED_RESULT = {
    state: 'pending',
    statuses: [
      {
        state: 'pending',
        description:
          "No status was reported for this commit on GitHub. See https://developer.github.com/v3/checks/ and " \
            "https://github.com/blog/1227-commit-status-api for details."
      }
    ]
  }.freeze
  IGNORE_PENDING_CHECKS = ENV["IGNORE_PENDING_COMMIT_CHECKS"].to_s.split(",").freeze

  def initialize(project, reference, stage: nil)
    @project = project
    @reference = reference # for display
    @commit = project.repo_commit_from_ref(reference) # ref->commit but also double-check a commit exists
    @stage = stage
  end

  # @return [String]
  def state
    combined_status.fetch(:state)
  end

  # @return [Array<Hash>]
  def statuses
    combined_status.fetch(:statuses).map(&:to_h)
  end

  # @return [NilClass]
  def expire_cache
    Rails.cache.delete(cache_key(@commit))
  end

  private

  # @return [Hash]
  def combined_status
    @combined_status ||= begin
      if @commit
        lookups = [
          -> { github_combined_status }
        ]
        if @stage
          lookups.concat [
            -> { release_status },
            -> { only_production_status },
            -> { plugin_statuses },
            -> { changeset_risks_status }
          ]
        end
        statuses = Samson::Parallelizer.map(lookups, db: true, &:call).flatten(1).compact
        merge_statuses(statuses)
      else
        {
          state: 'fatal',
          statuses: [{state: 'missing', description: "Reference #{@reference} not found"}]
        }
      end
    end
  end

  # Gets a reference's state, combining results from both the Status API, Checks API
  # @return [Hash]
  def github_combined_status
    expires_in = ->(reply) { cache_duration(reply) }
    Samson::DynamicTtlCache.cache_fetch_if true, cache_key(@commit), expires_in: expires_in do
      results = Samson::Parallelizer.map(
        [
          -> { octokit_error_as_status('checks') { github_check_status } },
          -> { octokit_error_as_status('status') { github_commit_status } }
        ],
        &:call
      ).compact.select { |result| result[:statuses].any? }

      results.empty? ? NO_STATUSES_REPORTED_RESULT.dup : merge_statuses(results)
    end
  end

  # Gets commit statuses using GitHub's check API. Currently parsing it to match status structure to better facilitate
  # transition to new API. See https://developer.github.com/v3/checks/runs/ and
  # https://developer.github.com/v3/checks/suites/ for details
  # @return [Hash]
  def github_check_status
    base_url = "repos/#{@project.repository_path}/commits/#{@commit}"
    preview_header = {Accept: 'application/vnd.github.antiope-preview+json'}

    check_suites = GITHUB.get("#{base_url}/check-suites", headers: preview_header).to_attrs.fetch(:check_suites)
    check_runs = GITHUB.get("#{base_url}/check-runs", headers: preview_header).to_attrs.fetch(:check_runs)

    # ignore pending unimportant
    check_suites.reject! do |s|
      check_state(s[:conclusion]) == "pending" &&
        (
          IGNORE_PENDING_CHECKS.include?(s.dig(:app, :name)) ||
          @project.ignore_pending_checks.to_s.split(",").include?(s.dig(:app, :name))
        )
    end

    overall_state = check_suites.
      map { |suite| check_state(suite[:conclusion]) }.
      max_by { |state| STATE_PRIORITY.index(state.to_sym) }

    statuses = check_runs.map do |check_run|
      {
        state: check_state(check_run[:conclusion]),
        description: ApplicationController.helpers.markdown(check_run[:output][:summary]),
        context: check_run[:name],
        target_url: check_run[:html_url],
        updated_at: check_run[:started_at]
      }
    end
    statuses += missing_check_runs_statuses(check_suites, check_runs)

    {state: overall_state || 'pending', statuses: statuses}
  end

  # @return [Array<Hash>]
  def missing_check_runs_statuses(check_suites, check_runs)
    reported = check_runs.map { |c| c.dig_fetch(:check_suite, :id) }
    pending_suites = check_suites.reject { |s| reported.include?(s.fetch(:id)) }
    pending_suites.map do |suite|
      name = suite.dig_fetch(:app, :name)
      {
        state: "pending",
        description: "Check #{name.inspect} has not reported yet",
        context: name,
        target_url: github_pr_checks_url(suite),
        updated_at: Time.now
      }
    end
  end

  # convert github api url to html url without doing another request for the PR
  # @return [String]
  def github_pr_checks_url(suite)
    return unless pr = suite.fetch(:pull_requests).first
    "#{pr[:url].sub('://api.', '://').sub('/repos/', '/').sub('/pulls/', '/pull/')}/checks"
  end

  # @return [Hash]
  def github_commit_status
    GITHUB.combined_status(@project.repository_path, @commit).to_h
  end

  # Show if included PRs are missing risks
  # There can be lots of PRs, so only use a single status
  # Ignore if all PRs are "None" risk or no PRs (return nil)
  # TODO: pass in commit to changeset to avoid extra commit resolution
  # TODO: parse risk level and display "pending" for "High" risks
  # @return [Hash, NilClass]
  def changeset_risks_status
    return unless ENV["COMMIT_STATUS_RISKS"]
    return unless previous = @stage.deploys.succeeded.first
    pull_requests = Changeset.new(@stage.project, previous.commit, @reference).pull_requests
    count = pull_requests.count(&:missing_risks?)

    if count > 0
      {
        state: "error",
        statuses: [{
          state: "Missing risks",
          description: "Risks section missing or failed to parse risks on #{count} PRs",
          updated_at: 1.minute.ago # do not cache for long so user can update the PR
        }]
      }
    end
  end

  # merges multiple statuses into a single status
  # @return [Hash]
  def merge_statuses(statuses)
    statuses[1..].each_with_object(statuses[0].dup) do |status, merged|
      merged[:state] = [merged.fetch(:state), status.fetch(:state)].max_by { |s| STATE_PRIORITY.index(s.to_sym) }
      merged.fetch(:statuses).concat(status.fetch(:statuses))
    end
  end

  # @return [String]
  def check_state(check_conclusion)
    case check_conclusion
    when *CHECK_STATE[:success] then 'success'
    when *CHECK_STATE[:error] then 'error'
    when *CHECK_STATE[:failure] then 'failure'
    when nil then 'pending'
    else raise "Unknown Check conclusion: #{check_conclusion}"
    end
  end

  # @return [Integer] seconds
  def cache_duration(github_result)
    statuses = github_result[:statuses]
    if github_result == NO_STATUSES_REPORTED_RESULT # does not have any statuses, chances are commit is new
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

  # checks if other stages that deploy to the same hosts as this stage have deployed a newer release
  # @return [nil, Hash]
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

  # Check if ref has been deployed to any non-production stages first if deploying to production
  def only_production_status
    return if !@stage.production? || @stage.project.deployed_to_non_production_stage?(@commit)

    {
      state: "pending",
      statuses: [{
        state: "Production Only Reference",
        description: "#{@reference} has not been deployed to a non-production stage."
      }]
    }
  end

  # @return [Array<Hash>]
  def plugin_statuses
    Samson::Hooks.fire(:ref_status, @stage, @reference, @commit).compact
  end

  # @return [Gem::Version, NilClass]
  def version(reference)
    return unless plain = reference[Release::VERSION_REGEX, 1]
    Gem::Version.new(plain)
  end

  # optimized to sql instead of AR fanciness to make it go from 1s -> 0.01s on our worst case stage
  # @return [Array<String>]
  def last_deployed_references
    last_deployed = deploy_scope.pluck(Arel.sql('max(deploys.id)'))
    Deploy.reorder(id: :asc).where(id: last_deployed).pluck(Arel.sql('distinct reference, id')).map(&:first)
  end

  def deploy_scope
    @deploy_scope ||= Deploy.reorder(nil).succeeded.where(stage_id: @stage.influencing_stage_ids).group(:stage_id)
  end

  # don't blow up when github is down, but show a nice error
  def octokit_error_as_status(type)
    yield
  rescue Octokit::ClientError => e
    Rails.logger.error(e) # log error for further debugging if it's not 404.
    {
      state: "missing",
      statuses: [{
        context: "Reference", # for releases/show.html.erb
        state: "missing",
        description: "Unable to get commit #{type}.",
        updated_at: Time.now # needed for #cache_duration
      }]
    }
  end
end
