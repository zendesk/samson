# frozen_string_literal: true
require_relative "../../test_helper"

SingleCov.covered!

describe Kubernetes::RoleVerifier do
  describe '.verify' do
    let(:role) do
      YAML.load_stream(read_kubernetes_sample_file('kubernetes_deployment.yml')).map(&:deep_symbolize_keys)
    end
    let(:spec) { role[0][:spec][:template][:spec] }
    let(:job_role) do
      [YAML.load(read_kubernetes_sample_file('kubernetes_job.yml')).deep_symbolize_keys]
    end
    let(:pod_role) do
      [{kind: 'Pod', metadata: {name: 'my-map'}, spec: {containers: [{name: "foo"}]}}]
    end
    let(:role_json) { role.to_json }
    let(:errors) do
      elements = Kubernetes::Util.parse_file(role_json, 'fake.json').map(&:deep_symbolize_keys)
      Kubernetes::RoleVerifier.new(elements).verify
    end

    it "works" do
      errors.must_be_nil
    end

    it "allows ConfigMap" do
      role_json[-1...-1] = ", #{{kind: 'ConfigMap', metadata: {name: 'my-map'}}.to_json}"
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
      Kubernetes::RoleVerifier.new(["bad", {kind: "Good"}]).verify.must_equal ["Only hashes supported"]
    end

    it "reports invalid types" do
      role.first[:kind] = "Ohno"
      errors.to_s.must_include "Unsupported combination of kinds: Ohno + Service, supported"
    end

    it "allows only Job" do
      role.replace(job_role)
      errors.must_be_nil
    end

    it "reports missing name" do
      role.first[:metadata].delete(:name)
      errors.must_equal ["Needs a metadata.name"]
    end

    it "reports non-unique namespaces since that would break pod fetching" do
      role.first[:metadata][:namespace] = "default"
      errors.to_s.must_include "Namespaces need to be unique"
    end

    it "reports multiple services" do
      role << role.last.dup
      errors.to_s.must_include "Unsupported combination of kinds: Deployment + Service + Service, supported"
    end

    it "reports numeric cpu" do
      role.first[:spec][:template][:spec][:containers].first[:resources] = {limits: {cpu: 1}}
      errors.must_include "Numeric cpu limits are not supported"
    end

    it "reports missing containers" do
      role.first[:spec][:template][:spec].delete(:containers)
      errors.must_include "Deployment/DaemonSet/Job/Pod need at least 1 container"
    end

    it "ignores unknown types" do
      role << {kind: 'Ooops'}
    end

    # if there are multiple containers they each need a name ... so enforcing this from the start
    it "reports missing name for containers" do
      spec[:containers][0].delete(:name)
      errors.must_equal ['Containers need a name']
    end

    it "reports bad container names" do
      spec[:containers][0][:name] = 'foo_bar'
      errors.must_equal ["Container name foo_bar did not match \\A[a-zA-Z0-9]([-a-zA-Z0-9]*[a-zA-Z0-9])?\\z"]
    end

    # release_doc does not support that and it would lead to chaos
    it 'reports job mixed with deploy' do
      role.concat job_role
      errors.to_s.must_include "Unsupported combination of kinds: Deployment + Job + Service, supported"
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
      errors.must_be_nil
    end

    it "works with proper annotations" do
      role.first[:spec][:template][:metadata][:annotations] = { 'secret/FOO' => 'bar' }
      errors.must_be_nil
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

    describe "#verify_prerequisites" do
      before do
        role.pop
        role.first[:kind] = "Job"
        role.first[:spec][:template][:spec][:restartPolicy] = "Never"
        role.first[:spec][:template][:metadata][:annotations] = {"samson/prerequisite": 'true'}
      end

      it "does not report valid prerequisites" do
        errors.must_equal nil
      end

      it "does not report valid prerequisites for pod" do
        assert role.first.delete(:spec)
        role.first[:kind] = "Pod"
        role.first[:metadata][:annotations] = {"samson/prerequisite": 'true'}
        role.first[:spec] = {containers: [{name: "Foo"}]}
        errors.must_equal nil
      end

      it "reports invalid prerequisites" do
        role.first[:kind] = "Deployment"
        errors.must_include "Only elements with type Job, Pod can be prerequisites."
      end
    end

    describe 'pod' do
      let(:role) { pod_role }

      it "allows only Pod" do
        errors.must_equal nil
      end

      it "fails without containers" do
        role[0][:spec][:containers].clear
        errors.must_equal ["Deployment/DaemonSet/Job/Pod need at least 1 container"]
      end

      it "fails without name" do
        role[0][:spec][:containers][0].delete :name
        errors.must_equal ["Containers need a name"]
      end
    end

    describe '#verify_job_restart_policy' do
      let(:expected) { ["Job spec.template.spec.restartPolicy must be one of Never/OnFailure"] }
      before { role.replace(job_role) }

      it "reports missing restart policy" do
        spec.delete(:restartPolicy)
        errors.must_equal expected
      end

      it "reports bad restart policy" do
        spec[:restartPolicy] = 'Always'
        errors.must_equal expected
      end
    end

    describe '#verify_project_and_role_consistent' do
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

    describe "#verify_host_volume_paths" do
      with_env KUBERNETES_ALLOWED_VOLUME_HOST_PATHS: '/data/,/foo/bar'

      before do
        spec[:volumes] = [
          {hostPath: {path: '/data'}},
          {hostPath: {path: '/data/'}},
          {hostPath: {path: '/data/bar'}}, # subdirectories are ok too
          {hostPath: {path: '/foo/bar/'}}
        ]
      end

      it "allows valid paths" do
        errors.must_be_nil
      end

      it "does not allow bad paths" do
        spec[:volumes][0][:hostPath][:path] = "/foo"
        errors.must_equal ["Only volume host paths /data/, /foo/bar/ are allowed, not /foo/."]
      end
    end
  end

  describe '.map_attributes' do
    def call(path, elements)
      Kubernetes::RoleVerifier.new(elements).send(:map_attributes, path)
    end

    it "finds simple" do
      call([:a], [{a: 1}, {a: 2}]).must_equal [1, 2]
    end

    it "finds nested" do
      call([:a, :b], [{a: {b: 1}}, {a: {b: 2}}]).must_equal [1, 2]
    end

    it "finds arrays" do
      call([:a], [{a: [1]}, {a: [2]}]).must_equal [[1], [2]]
    end

    it "finds through nested arrays" do
      call([:a, :b], [{a: [{b: 1}, {b: 2}]}, {a: [{b: 3}]}]).must_equal [[1, 2], [3]]
    end
  end
end
