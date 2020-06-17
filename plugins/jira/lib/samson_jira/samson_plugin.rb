# frozen_string_literal: true

require 'base64'

module SamsonJira
  class SamsonPlugin < Rails::Engine
  end

  def self.jira_base_url
    ENV['JIRA_BASE_URL'].to_s[/(.*)\/[a-z]/, 1]
  end

  def self.transition_jira_tickets(deploy, output)
    return unless deploy.succeeded?
    return unless url = jira_base_url
    return unless user = ENV['JIRA_USER']
    return unless token = ENV['JIRA_TOKEN']
    return unless prefix = deploy.project.jira_issue_prefix.presence
    return unless transition_id = deploy.stage.jira_transition_id.presence

    issues = deploy.changeset.jira_issues
    issues = issues.select { |i| i.reference.start_with?("#{prefix}-") }
    issues.each do |issue|
      begin
        response =
          Faraday.post "#{url}/rest/api/3/issue/#{CGI.escape(issue.reference)}/transitions" do |request|
            request.options.open_timeout = 2
            request.options.timeout = 5
            request.headers['Authorization'] = "Basic #{Base64.strict_encode64("#{user}:#{token}")}"
            request.headers['Content-Type'] = 'application/json'
            request.headers['Accept'] = 'application/json'
            request.body = {transition: {id: transition_id}}.to_json
          end

        if response.success?
          output.puts "Transitioned JIRA issue #{issue.url}"
        else
          errors = JSON.parse(response.body).fetch("errorMessages").join(", ")
          output.puts "Failed to transition JIRA issue #{issue.url}:\n#{errors}"
        end
      end
    end
  end
end

Samson::Hooks.view :stage_form, "samson_jira"
Samson::Hooks.view :project_form, "samson_jira"

Samson::Hooks.callback :stage_permitted_params do
  :jira_transition_id
end

Samson::Hooks.callback :project_permitted_params do
  :jira_issue_prefix
end

Samson::Hooks.callback :after_deploy do |deploy, job_execution|
  SamsonJira.transition_jira_tickets(deploy, job_execution.output)
end
