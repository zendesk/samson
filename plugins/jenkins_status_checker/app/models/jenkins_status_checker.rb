# frozen_string_literal: true
require 'jenkins_api_client'
require 'singleton'
# checks jenkins staging status and publishes unstable builds checklist
class JenkinsStatusChecker
  include Singleton

  def checklist
    items = []
    result = check_jenkins

    if result.is_a?(String) # error
      items << result
    else
      result["jobs"].each do |job|
        items << "#{job["name"]} is #{job["color"]}" if job["color"] != "blue"
      end
    end
    items << "All projects stable!" if items.empty?
    items
  end

  private

  def check_jenkins
    client.api_get_request(ENV.fetch('JENKINS_STATUS_CHECKER'))
  rescue
    "Error: #{$!}"
  end

  def client
    @client ||= \
      JenkinsApi::Client.new(
        server_url: ENV.fetch('JENKINS_URL'),
        username: ENV.fetch('JENKINS_USERNAME'),
        password: ENV.fetch('JENKINS_API_KEY')
      )
  end
end
