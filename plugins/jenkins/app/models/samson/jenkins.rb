# rubocop:disable Metrics/LineLength
require 'jenkins_api_client'

module Samson
  class Jenkins
    URL = ENV['JENKINS_URL']
    USERNAME = ENV['JENKINS_USERNAME']
    API_KEY = ENV['JENKINS_API_KEY']

    attr_reader :job_name, :deploy

    def initialize(job_name, deploy)
      @job_name = job_name
      @deploy = deploy
    end

    def build
      opts = {'build_start_timeout' => 60}
      originated_from = deploy.project.name + '_' + deploy.stage.name + '_' + deploy.reference
      client.job.build(job_name, {'buildStartedBy' => deploy.user.name, 'originatedFrom' => originated_from, 'commit' => deploy.job.commit}, opts).to_i
    rescue Timeout::Error => e
      "Jenkins '#{job_name}' build failed to start in a timely manner.  #{e.class} #{e}"
    rescue JenkinsApi::Exceptions::ApiException => e
      "Problem while waiting for '#{job_name}' to start.  #{e.class} #{e}"
    end

    def job_status(jenkins_job_id)
      response(jenkins_job_id)['result']
    end

    def job_url(jenkins_job_id)
      response(jenkins_job_id)['url']
    end

    private

    def response(jenkins_job_id)
      @response ||= client.job.get_build_details(job_name, jenkins_job_id)
    end

    def client
      @@client ||= JenkinsApi::Client.new(server_url: URL, username: USERNAME, password: API_KEY).tap do |cli|
        cli.logger = Rails.logger
      end
    end
  end
end
