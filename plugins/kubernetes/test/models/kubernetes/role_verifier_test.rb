# frozen_string_literal: true
require_relative "../../test_helper"

SingleCov.covered!

describe Kubernetes::RoleVerifier do
  describe '.verify' do
    let(:role) do
      YAML.load_stream(read_kubernetes_sample_file('kubernetes_deployment.yml')).map(&:with_indifferent_access)
    end
    let(:job_role) do
      [YAML.load(read_kubernetes_sample_file('kubernetes_job.yml')).with_indifferent_access]
    end
    let(:role_json) { role.to_json }
    let(:errors) do
      elements = Kubernetes::Util.parse_file(role_json, 'fake.json')
      Kubernetes::RoleVerifier.new(elements).verify
    end

    it "works" do
      errors.must_equal nil
    end

    it "fails nicely with empty Hash template" do
      role_json.replace "{}"
      refute errors.empty?
    end

    it "fails nicely with empty Array template" do
      role_json.replace "[]"
      errors.must_equal ["No content found"]
    end

    it "fails nicely with false" do
      elements = Kubernetes::Util.parse_file('---', 'fake.yml')
      errors = Kubernetes::RoleVerifier.new(elements).verify
      errors.must_equal ["No content found"]
    end

    it "fails nicely with bad template" do
      role_json.replace '["bad", {"kind": "Good"}]'
      errors.to_s.must_include "Unsupported combination of kinds:  + Good"
    end

    it "reports invalid types" do
      role.first[:kind] = "Ohno"
      errors.must_include "Unsupported combination of kinds: Ohno + Service" \
        ", supported combinations are: Deployment, DaemonSet, Deployment + Service, Job"
    end

    it "allows only Job" do
      role.replace(job_role)
      errors.must_equal nil
    end

    it "reports missing name" do
      role.first[:metadata].delete(:name)
      errors.must_equal ["Needs a metadata.name"]
    end

    it "reports multiple services" do
      role << role.last.dup
      errors.must_include "Unsupported combination of kinds: Deployment + Service + Service" \
        ", supported combinations are: Deployment, DaemonSet, Deployment + Service, Job"
    end

    it "reports numeric cpu" do
      role.first[:spec][:template][:spec][:containers].first[:resources] = {limits: {cpu: 1}}
      errors.must_include "Numeric cpu limits are not supported"
    end

    it "reports missing containers" do
      role.first[:spec][:template][:spec].delete(:containers)
      errors.must_include "Deployment/DaemonSet/Job need at least 1 container"
    end

    it "ignores unknown types" do
      role << {kind: 'Ooops'}
    end

    # kubernetes somehow needs them to have names
    it "reports missing name for job containers" do
      role.replace(job_role)
      role[0][:spec][:template][:spec][:containers][0].delete(:name)
      errors.must_equal ['Job containers need a name']
    end

    # release_doc does not support that and it would lead to chaos
    it 'reports job mixed with deploy' do
      role.concat job_role
      errors.must_include "Unsupported combination of kinds: Deployment + Job + Service" \
        ", supported combinations are: Deployment, DaemonSet, Deployment + Service, Job"
    end

    it "reports non-string labels" do
      role.first[:metadata][:labels][:role_id] = 1
      errors.must_include "Deployment metadata.labels.role_id must be a String"
    end

    it "reports invalid labels" do
      role.first[:metadata][:labels][:role] = 'foo_bar'
      errors.must_include "Deployment metadata.labels.role must match /\\A[a-zA-Z0-9]([-a-zA-Z0-9]*[a-zA-Z0-9])?\\z/"
    end

    it "allows valid labels" do
      role.first[:metadata][:labels][:foo] = 'KubeDNS'
      errors.must_equal nil
    end

    it "works with proper annotations" do
      role.first[:spec][:template][:metadata][:annotations] = { 'secret/FOO' => 'bar' }
      errors.must_equal nil
    end

    it "reports invalid annotations" do
      role.first[:spec][:template][:metadata][:annotations] = ['foo', 'bar']
      errors.must_include "Annotations must be a hash"
    end

    it "reports non-string env values" do
      role.first[:spec][:template][:spec][:containers][0][:env] = {
        name: 'XYZ_PORT',
        value: 1234 # can happen when using yml configs
      }
      errors.must_include "Env values 1234 must be strings."
    end

    describe 'verify_job_restart_policy' do
      let(:expected) { ["Job spec.template.spec.restartPolicy must be one of Never/OnFailure"] }
      before { role.replace(job_role) }

      it "reports missing restart policy" do
        role[0][:spec][:template][:spec].delete(:restartPolicy)
        errors.must_equal expected
      end

      it "reports bad restart policy" do
        role[0][:spec][:template][:spec][:restartPolicy] = 'Always'
        errors.must_equal expected
      end
    end

    describe 'inconsistent labels' do
      let(:error_message) { "Project and role labels must be consistent across Deployment/DaemonSet/Service/Job" }

      # this is not super important, but adding it for consistency
      it "reports missing job labels" do
        role.replace(job_role)
        role[0][:metadata][:labels].delete(:role)
        errors.must_equal [
          "Missing project or role for Job metadata.labels",
          error_message
        ]
      end

      it "reports missing labels" do
        role.first[:spec][:template][:metadata][:labels].delete(:project)
        errors.must_equal [
          "Missing project or role for Deployment spec.template.metadata.labels",
          error_message
        ]
      end

      it "reports missing label section" do
        role.first[:spec][:template][:metadata].delete(:labels)
        errors.must_equal [
          "Missing project or role for Deployment spec.template.metadata.labels",
          error_message
        ]
      end

      it "reports inconsistent deploy label" do
        role.first[:spec][:template][:metadata][:labels][:project] = 'other'
        errors.must_include error_message
      end

      it "reports inconsistent service label" do
        role.last[:spec][:selector][:project] = 'other'
        errors.must_include error_message
      end
    end
  end
end
