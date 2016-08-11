# frozen_string_literal: true
module Kubernetes
  module Api
    class Job
      def initialize(api_job)
        @job = api_job
      end

      def name
        @job.metadata.try(:name)
      end

      def namespace
        @job.metadata.try(:namespace)
      end

      def failure?
        @job.status == 'Failure'
      end

      def complete?
        (@job.status.conditions || []).detect { |c| break c['status'] == 'True' if c['type'] == 'Complete' }
      end
    end
  end
end
