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
      client.job.build(job_name, {'buildStartedBy' => deploy.user.name, 'originatedFrom' => deploy.stage.name}, opts).to_i
    rescue Timeout::Error => e
      "Jenkins '#{job_name}' build failed to start in a timely manner.  #{e.class} #{e}"
    rescue JenkinsApi::Exceptions::ApiException => e
      "Problem while waiting for '#{job_name}' to start.  #{e.class} #{e}"
    end

    def job_status(jenkins_job_id)
      client.job.get_build_details(job_name, jenkins_job_id)['result']
    end

    private

    def client
      @@client ||= JenkinsApi::Client.new(:server_url => URL, :username => USERNAME, :password => API_KEY)
    end
  end
end
