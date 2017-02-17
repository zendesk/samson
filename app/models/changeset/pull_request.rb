# frozen_string_literal: true
class Changeset::PullRequest
  # Common patterns
  CODE_ONLY = "[A-Z][A-Z\\d]+-\\d+" # e.g., S4MS0N-123, SAM-456
  PUNCT = "\\s|\\p{Punct}|~|="

  WEBHOOK_FILTER = /(^|\s)\[samson review\]($|\s)/i

  # Matches a markdown section heading named "Risks".
  RISKS_SECTION = /^\s*#*\s*Risks?\s*#*\s*\n(?:\s*[-=]*\s*\n)?/i

  # Matches URLs to JIRA issues.
  JIRA_ISSUE_URL = %r[https?:\/\/[\da-z\.\-]+\.[a-z\.]{2,6}\/browse\/#{CODE_ONLY}(?=#{PUNCT}|$)]

  # Matches "VOICE-1234" or "[VOICE-1234]"
  JIRA_CODE_TITLE = /(\[)*(#{CODE_ONLY})(\])*/

  # Matches "VOICE-1234" only
  JIRA_CODE = /(?<=#{PUNCT}|^)(#{CODE_ONLY})(?=#{PUNCT}|$)/

  # Github pull request events can be triggered by a number of actions such as 'labeled', 'assigned'
  # Actions which aren't related to a code push should not trigger a samson deploy.
  # Docs on the pull request event: https://developer.github.com/v3/activity/events/types/#pullrequestevent
  VALID_ACTIONS = ['opened', 'edited', 'synchronized'].freeze

  # Finds the pull request with the given number.
  #
  # repo   - The String repository name, e.g. "zendesk/samson".
  # number - The Integer pull request number.
  #
  # Returns a ChangeSet::PullRequest describing the PR or nil if it couldn't
  #   be found.
  def self.find(repo, number)
    data = Rails.cache.fetch([self, repo, number].join("-")) do
      GITHUB.pull_request(repo, number)
    end

    new(repo, data)
  rescue Octokit::NotFound
    nil
  end

  def self.changeset_from_webhook(project, params = {})
    data = Sawyer::Resource.new(Octokit.agent, params['pull_request'].to_unsafe_h)
    new(project.github_repo, data)
  end

  # Webhook events that are valid should be related to a pr code push or someone adding [samson review]
  # to the description. The actions related to a code push are 'opened' and 'synchronized'
  # The 'edited' action gets sent when the PR description is edited. To trigger a deploy from an edit - it
  # should only be when the edit is related to adding the text [samson review]
  def self.valid_webhook?(params)
    data = params['pull_request'] || {}
    action = params.dig('github', 'action')
    return false unless data['state'] == 'open' && (VALID_ACTIONS.include? action)

    if action == 'edited'
      previous_desc = params.dig('github', 'changes', 'body', 'from')
      return false if !previous_desc || (previous_desc =~ WEBHOOK_FILTER && data['body'] =~ WEBHOOK_FILTER)
    end

    !(data['body'] =~ WEBHOOK_FILTER).nil?
  end

  attr_reader :repo

  def initialize(repo, data)
    @repo = repo
    @data = data
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

  def risky?
    risks.present?
  end

  def risks
    return @risks if defined?(@risks)
    @risks = parse_risks(@data.body.to_s)
    @risks = nil if @risks =~ /\A\s*\-?\s*None\Z/i
    @risks
  end

  def jira_issues
    @jira_issues ||= parse_jira_issues
  end

  def service_type
    'pull_request' # Samson webhook category
  end

  private

  def parse_risks(body)
    body.to_s.split(RISKS_SECTION, 2)[1].to_s.strip.presence
  end

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
