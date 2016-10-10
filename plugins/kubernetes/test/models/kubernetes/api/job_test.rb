# frozen_string_literal: true
require_relative '../../../test_helper'

SingleCov.covered!

describe Kubernetes::Api::Job do
  let(:job_name) { 'test_job' }
  let(:namespace) { 'test_ns' }

  let(:job) { Kubernetes::Api::Job.new(build_kubeclient_job) }

  describe '#name' do
    it 'reads job name' do
      job.name.must_equal job_name
    end
  end

  describe '#namespace' do
    it 'reads job namespace' do
      job.namespace.must_equal namespace
    end
  end

  describe '#failure?' do
    let(:job) { Kubernetes::Api::Job.new(build_kubeclient_job) }

    it 'is false when API returns a complete job data' do
      refute job.failure?
    end

    it 'is false failed when API returns a valid condition' do
      job.instance_variable_get(:@job).status.conditions = [{'type': 'Ready', 'status': 'True'}]
      refute job.failure?
    end

    it 'is true when API returns failure data' do
      job.instance_variable_get(:@job).status = 'Failure'
      assert job.failure?
    end
  end

  describe '#complete?' do
    let(:job) { Kubernetes::Api::Job.new(build_kubeclient_job) }

    it 'is true when API returns a complete job data' do
      assert job.complete?
    end

    it 'is false when API returns invalid conditions' do
      job.instance_variable_get(:@job).status.conditions = nil
      refute job.complete?
    end

    it 'is false when API returns an empty condition' do
      job.instance_variable_get(:@job).status.conditions = []
      refute job.complete?
    end

    it 'is false when API returns non-empty conditions but no status' do
      job.instance_variable_get(:@job).status.conditions = [{'type': 'Ready', 'status': 'True'}]
      refute job.complete?
    end

    it 'is false when API returns conditions for a incompleted job' do
      job.instance_variable_get(:@job).status.conditions = [{'type': 'Complete', 'status': 'False'}]
      refute job.complete?
    end
  end

  private

  def build_kubeclient_job
    data = {
      metadata: {
        name: job_name,
        namespace: namespace,
      },
      status: {
        conditions: [{type: 'Complete', status: 'True'}]
      },
      spec: {
        template: {
          metadata: {
            labels: {'jobName' => job_name}
          }
        }
      }
    }
    Kubeclient::Resource.new(JSON.parse(data.to_json))
  end
end
