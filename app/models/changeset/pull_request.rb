# frozen_string_literal: true
class Changeset::PullRequest
  # Common patterns
  CODE_ONLY = "[A-Z][A-Z\\d]+-\\d+" # e.g., S4MS0N-123, SAM-456
  PUNCT = "\\s|\\p{Punct}|~|="

  WEBHOOK_FILTER = /(^|\s)\[samson review\]($|\s)/i.freeze

  # Matches URLs to JIRA issues.
  JIRA_ISSUE_URL = %r[https?://[\da-z.\-]+\.[a-z.]{2,6}/browse/#{CODE_ONLY}(?=#{PUNCT}|$)].freeze

  # Matches "VOICE-1234" or "[VOICE-1234]"
  JIRA_CODE_TITLE = /(\[)*(#{CODE_ONLY})(\])*/.freeze

  # Matches "VOICE-1234" only
  JIRA_CODE = /(?<=#{PUNCT}|^)(#{CODE_ONLY})(?=#{PUNCT}|$)/.freeze

  # Github pull request events can be triggered by a number of actions such as 'labeled', 'assigned'
  # Actions which aren't related to a code push should not trigger a samson deploy.
  # Docs on the pull request event: https://developer.github.com/v3/activity/events/types/#pullrequestevent
  VALID_ACTIONS = ['opened', 'edited', 'synchronize'].freeze

  class << self
    # Finds the pull request with the given number.
    #
    # @param [String] repository name, e.g. "zendesk/samson".
    # @param [Integer] pull request number
    # @return [ChangeSet::PullRequest, nil]
    def find(repo, number)
      data = Rails.cache.fetch(cache_key(repo, number)) do
        GITHUB.pull_request(repo, number)
      end
      new repo, data
    rescue Octokit::NotFound
      nil
    end

    # store a PR in the cache for later use and wrap it in ChangeSet::PullRequest, mirroring .find
    #
    # @param [String] repository name, e.g. "zendesk/samson".
    # @param [Hash, Sawyer::Resource] repository name, e.g. "zendesk/samson".
    # @return [ChangeSet::PullRequest]
    def cache(repo, payload)
      data = fake_api_response(payload)
      Rails.cache.write cache_key(repo, data.number), data
      new repo, data
    end

    def changeset_from_webhook(project, payload)
      new project.repository_path, fake_api_response(payload)
    end

    # Webhook events that are valid should be related to a pr code push or someone adding [samson review]
    # to the description. The actions related to a code push are 'opened' and 'synchronized'
    # The 'edited' action gets sent when the PR description is edited. To trigger a deploy from an edit - it
    # should only be when the edit is related to adding the text [samson review]
    def valid_webhook?(payload)
      data = payload['pull_request'] || {}
      action = payload['action']
      return false if data['state'] != 'open' || !VALID_ACTIONS.include?(action)

      if action == 'edited'
        previous_desc = payload.dig('changes', 'body', 'from')
        return false if !previous_desc || (previous_desc =~ WEBHOOK_FILTER && data['body'] =~ WEBHOOK_FILTER)
      end

      data['body'].match? WEBHOOK_FILTER
    end

    private

    def fake_api_response(payload)
      Sawyer::Resource.new(
        Octokit.agent,
        payload.deep_symbolize_keys.fetch(:pull_request) # need to symbolize or caching breaks
      )
    end

    def cache_key(repo, number)
      [self, repo, number].join("-")
    end
  end

  attr_reader :repo

  def initialize(repo, data)
    @repo = repo
    @data = data # Sawyer::Resource
  end

  delegate :number, :title, :additions, :deletions, to: :@data

  def title_without_jira
    title.gsub(JIRA_CODE_TITLE, "").strip
  end

  def url
    "#{Rails.application.config.samson.github.web_url}/#{repo}/pull/#{number}"
  end

  def reference
    "##{number}"
  end

  def sha
    @data['head']['sha']
  end

  # does not include refs/head
  def branch
    @data['head']['ref']
  end

  def state
    @data['state']
  end

  def users
    users = [@data['user'], @data['merged_by']]
    users.compact.map { |user| Changeset::GithubUser.new(user) }.uniq
  end

  def created_at
    @data['created_at']
  end

  def risky?
    risks.present?
  end

  def risks
    return @risks if defined?(@risks)
    @risks = parse_risks(@data.body.to_s)
    if @risks&.match?(/\A\s*-?\s*None\Z/i)
      @risks = nil
      @missing_risks = false
    else
      @missing_risks = @risks.nil?
    end
    @risks
  end

  def missing_risks?
    risks
    @missing_risks
  end

  def jira_issues
    @jira_issues ||= parse_jira_issues
  end

  def service_type
    'pull_request' # Samson webhook category
  end

  def message
    nil
  end

  private

  def section_content(section_title, text)
    # ### Risks or Risks followed by === / ---
    desired_header_regexp = "^(?:\\s*#+\\s*\\W*\\s*#{section_title}.*"\
      "|\\s*\\W*\\s*#{section_title}.*\\n\\s*(?:-{2,}|={2,}))\\n"
    content_regexp = '([\W\w]*?)' # capture all section content, including new lines, but not next header
    next_header_regexp = '(?=^(?:\s*#+|.*\n\s*(?:-{2,}|={2,}\s*\n))|\z)'

    text[/#{desired_header_regexp}#{content_regexp}#{next_header_regexp}/i, 1]
  end

  def parse_risks(body)
    body_stripped = ActionController::Base.helpers.strip_tags(body)
    section_content('Risks', body_stripped).to_s.rstrip.sub(/\A\s*\n/, "").presence
  end

  # @return [Array<Changeset::JiraIssue>]
  def parse_jira_issues
    custom_jira_url = ENV['JIRA_BASE_URL']
    title_and_body = "#{title} #{body}"
    jira_issue_map = {}
    if custom_jira_url
      title_and_body.scan(JIRA_CODE).each do |match|
        jira_issue_map[match[0]] = custom_jira_url + match[0]
      end
    end
    # explicit URLs should take precedence for issue links
    title_and_body.scan(JIRA_ISSUE_URL).each do |match|
      jira_issue_map[match.match(JIRA_CODE)[0]] = match
    end
    jira_issue_map.values.map { |x| Changeset::JiraIssue.new(x) }
  end

  def body
    @data.body.to_s
  end
end
