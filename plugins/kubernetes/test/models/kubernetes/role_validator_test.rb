# frozen_string_literal: true
require_relative "../../test_helper"

SingleCov.covered!

describe Kubernetes::RoleValidator do
  let(:deployment_role) do
    YAML.load_stream(read_kubernetes_sample_file('kubernetes_deployment.yml')).map(&:deep_symbolize_keys)
  end
  let(:role) { deployment_role }

  describe "#validate" do
    let(:spec) { role[0][:spec][:template][:spec] }
    let(:job_role) do
      [YAML.safe_load(read_kubernetes_sample_file('kubernetes_job.yml')).deep_symbolize_keys]
    end
    let(:cron_job_role) do
      [YAML.safe_load(read_kubernetes_sample_file('kubernetes_cron_job.yml')).deep_symbolize_keys]
    end
    let(:pod_role) do
      [{kind: 'Pod', apiVersion: 'v1', metadata: {name: 'my-map', labels: labels}, spec: {containers: [{name: "foo"}]}}]
    end
    let(:labels) { {project: "some-project", role: "some-role"} }
    let(:stateful_set_role) do
      [
        deployment_role[1],
        {
          kind: 'StatefulSet',
          apiVersion: 'apps/v1',
          metadata: {name: 'my-map', labels: labels},
          spec: {
            serviceName: 'foobar',
            selector: {matchLabels: labels},
            template: {
              metadata: {labels: labels},
              spec: {containers: [{name: 'foo'}]}
            }
          }
        }
      ]
    end
    let(:role_json) { role.to_json }
    let(:namespace) { "foo" }
    let(:project) { projects(:test) }
    let(:validator) do
      elements = Kubernetes::Util.parse_file(role_json, 'fake.json').map(&:deep_symbolize_keys)
      Kubernetes::RoleValidator.new(elements, project: project)
    end
    let(:errors) { validator.validate }

    it "works" do
      errors.must_be_nil
    end

    it "allows ConfigMap" do
      map = {kind: 'ConfigMap', apiVersion: 'v1', metadata: {name: 'my-map', labels: labels}}
      role_json[-1...-1] = ", #{map.to_json}"
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
      errors = Kubernetes::RoleValidator.new(elements, project: project).validate
      errors.must_equal ["No content found"]
    end

    it "fails nicely with bad template" do
      Kubernetes::RoleValidator.new(["bad", {kind: "Good"}], project: project).
        validate.must_equal ["Only hashes supported"]
    end

    it "allows invalid types" do
      role.first[:kind] = "Ohno"
      refute errors
    end

    it "does not allow multiple deployables" do
      role[1][:spec] = {containers: []}
      errors.must_include(
        "Only use a maximum of 1 template with containers, found: 2"
      )
    end

    it "does not allow ineffective securityContext" do
      role[0][:spec][:template][:spec][:securityContext] = {readOnlyRootFilesystem: true}
      errors.must_include(
        "securityContext.readOnlyRootFilesystem can only be set at the container level"
      )
    end

    describe 'StatefulSet' do
      before do
        stateful_set_role[0][:metadata][:name] = 'foobar'
        role.replace(stateful_set_role)
      end

      it "allows" do
        errors.must_equal nil
      end

      it "enforces service and serviceName consistency" do
        stateful_set_role[0][:metadata][:name] = 'nope'
        errors.must_equal ["Service metadata.name and StatefulSet spec.serviceName must be consistent"]
      end
    end

    describe 'PodDisruptionBudget' do
      before do
        role.push(
          kind: 'PodDisruptionBudget',
          apiVersion: 'policy/v1',
          metadata: {name: 'foo', labels: labels},
          spec: {selector: {matchLabels: labels}}
        )
      end

      it "allows" do
        errors.must_equal nil
      end

      it "shows inconsistent labels" do
        role[0][:metadata][:labels][:project] = 'nope'
        errors.must_equal ["Project and role labels must be consistent across resources"]
      end

      [
        [:minAvailable, 1, true],
        [:minAvailable, 2, false],
        [:minAvailable, "0%", true],
        [:minAvailable, "10%", true],
        [:minAvailable, "90%", false],
        [:minAvailable, "100%", false],
        [:maxUnavailable, 1, true],
        [:maxUnavailable, 0, false],
        [:maxUnavailable, "100%", true],
        [:maxUnavailable, "90%", true],
        [:maxUnavailable, "10%", true],
        [:maxUnavailable, "0%", false],
      ].each do |config, value, allowed|
        it "#{allowed ? "allows" : "forbids"} setting #{config} to #{value}" do
          role.last[:spec][config] = value
          if allowed
            errors.must_be_nil
          else
            errors.first.must_include "avoid eviction deadlock"
          end
        end
      end
    end

    it "allows Gateway" do
      map = {kind: 'Gateway', apiVersion: 'v1', metadata: {name: 'my-map', labels: labels}, spec: {selector: {a: "b"}}}
      role_json[-1...-1] = ", #{map.to_json}"
      errors.must_equal nil
    end

    it "allows only Job" do
      role.replace(job_role)
      errors.must_be_nil
    end

    it "allows only CronJob" do
      role.replace(cron_job_role)
      errors.must_be_nil
    end

    it "reports missing name" do
      role.first[:metadata].delete(:name)
      errors.must_equal ["Needs a metadata.name"]
    end

    ['CustomResourceDefinition', 'APIService'].each do |kind|
      it "allows #{kind} to not have a namespace" do
        role[0][:metadata].delete(:namespace)
        role[0][:kind] = kind
        refute errors
      end
    end

    it "allows multiple services" do
      role << role.last.dup
      errors.must_be_nil
    end

    it "does not fail on missing containers" do
      role.first[:spec][:template][:spec].delete(:containers)
      errors.must_be_nil
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
      errors.must_equal ["Container name foo_bar did not match \\A[a-zA-Z0-9]([-a-zA-Z0-9.]*[a-zA-Z0-9])?\\z"]
    end

    it "reports non-string labels" do
      role.first[:metadata][:labels][:role_id] = 1
      errors.must_include "Deployment metadata.labels.role_id is 1, but must be a String"
    end

    it "reports invalid labels" do
      role.first[:metadata][:labels][:role] = '_foo_'
      errors.must_include(
        'Deployment metadata.labels.role is "_foo_", but must match /\\A[a-zA-Z0-9]([-a-zA-Z0-9_.]*[a-zA-Z0-9])?\\z/'
      )
    end

    it "allows valid labels" do
      role.first[:metadata][:labels][:foo] = 'KubeDNS'
      errors.must_be_nil
    end

    it "works with proper annotations" do
      role.first[:spec][:template][:metadata][:annotations] = {'secret/FOO' => 'bar'}
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

    it "reports non-string annotations" do
      role.first[:metadata][:annotations] = {
        bar: true
      }
      role.first[:spec][:template][:metadata][:annotations] = {
        foo: 'XYZ_PORT',
        bar: 1234
      }
      errors.must_include "Annotation values true, 1234 must be strings."
    end

    it "fails when apiVersion is missing" do
      role[1].delete(:apiVersion)
      errors.must_include "Needs apiVersion specified"
    end

    describe "#validate_datadog_annotations" do
      it "passes when annotation matches container name" do
        role.first[:spec][:template][:metadata][:annotations] = {
          "ad.datadoghq.com/some-project.check_names": "['foo']"
        }
        assert_nil errors
      end

      it "fails when annotation does not match container name" do
        role.first[:spec][:template][:metadata][:annotations] = {
          "ad.datadoghq.com/some-other-project.check_names": "['foo']"
        }
        errors.must_equal ["Datadog annotation specified for non-existent container name: some-other-project"]
      end

      it "works with cron jobs" do
        role.replace(cron_job_role)
        role.first[:spec][:jobTemplate][:spec][:template][:metadata][:annotations] = {
          "ad.datadoghq.com/some-other-project.check_names": "['foo']"
        }
        errors.must_equal ["Datadog annotation specified for non-existent container name: some-other-project"]
      end

      it "works with pods" do
        role.replace(pod_role)
        role.first[:metadata][:annotations] = {
          "ad.datadoghq.com/some-other-project.check_names": "['foo']"
        }
        errors.must_equal ["Datadog annotation specified for non-existent container name: some-other-project"]
      end
    end

    describe "#validate_namespace" do
      before { project.kubernetes_namespace = kubernetes_namespaces(:test) }

      it "passes with correct namespaces" do
        role.each { |e| e[:metadata][:namespace] = "test" }
        errors.must_equal nil
      end

      it "passes without namespaces" do
        errors.must_equal nil
      end

      it "fails with forced default namespace" do
        role[0][:metadata][:namespace] = nil
        errors.must_equal ["Only use configured namespace \"test\", not [nil]"]
      end

      describe "with invalid namespace" do
        before { role[0][:metadata][:namespace] = "bar" }

        it "passes when namespace is not configured" do
          validator.instance_variable_set(:@project, nil)
          errors.must_equal nil
        end

        it "fails with invalid namespace" do
          errors.must_equal ["Only use configured namespace \"test\", not [\"bar\"]"]
        end
      end
    end

    describe "#validate_name_kinds_are_unique" do
      before { role.each { |r| r[:kind] = "foo" } }

      it "fails when there are duplicate kinds" do
        errors.to_s.must_include "Only use 1 per kind foo in a role"
      end

      it "ignores when using project namespace" do
        project.kubernetes_namespace = kubernetes_namespaces(:test)
        errors.must_be_nil
      end

      it "fails when services use hardcoded but duplicate names" do
        role.each do |r|
          r[:kind] = "Service"
          r[:metadata][:name] = "same"
          r.dig_set([:metadata, :annotations], "samson/keep_name": "true")
        end
        errors.to_s.must_include "Only use 1 per kind Service in a role"
      end

      it "allows duplicate kinds and names in different namespaces services use hardcoded but duplicate names" do
        role.each do |r|
          r[:kind] = "Service"
          r[:metadata][:name] = "same"
          r.dig_set([:metadata, :annotations], "samson/keep_name": "true")
        end
        role.last[:metadata][:namespace] = "other"
        errors.must_be_nil
      end

      it "allows duplicate kinds with distinct names" do
        role.each { |r| r.dig_set([:metadata, :annotations], "samson/keep_name": "true") }
        refute errors
      end

      it "allows duplicate IMMUTABLE_NAME_KINDS with different names" do
        role[0][:kind] = "ConfigMap"
        role[0][:spec][:template][:spec].delete :containers
        role << role[0].deep_dup
        role[0][:metadata][:name] = "other"
        errors.must_be_nil
      end
    end

    describe "#validate_team_labels" do
      with_env KUBERNETES_ENFORCE_TEAMS: "true"

      before do
        role[0][:metadata][:labels][:team] = "hey"
        role[1][:metadata][:labels][:team] = "hey"
        role[0][:spec][:template][:metadata][:labels][:team] = "ho"
      end

      it "passes when labels are added" do
        errors.must_be_nil
      end

      it "passes when spec is not required" do
        role.delete :spec
        errors.must_be_nil
      end

      describe "with missing labels" do
        before do
          role[0][:metadata][:labels].delete :team
          role[0][:spec][:template][:metadata][:labels].delete :team
        end

        it "fails" do
          errors.must_equal [
            "Deployment metadata.labels.team must be set",
            "Deployment spec.template.metadata.labels.team must be set"
          ]
        end

        it "does not fail when disabled" do
          with_env KUBERNETES_ENFORCE_TEAMS: nil do
            errors.must_be_nil
          end
        end
      end
    end

    describe "#validate_prerequisites_kinds" do
      before do
        role.pop
        role.first[:kind] = "Job"
        role.first[:spec][:template][:spec][:restartPolicy] = "Never"
        role.first[:metadata][:annotations] = {"samson/prerequisite": "true"}
      end

      it "does not report valid prerequisites" do
        errors.must_equal nil
      end

      it "does not report valid prerequisites for pod" do
        assert role.first.delete(:spec)
        role.first[:kind] = "Pod"
        role.first[:metadata][:annotations] = {"samson/prerequisite": "true"}
        role.first[:spec] = {containers: [{name: "Foo"}]}
        errors.must_equal nil
      end

      it "reports invalid prerequisites" do
        role.first[:kind] = "Deployment"
        errors.must_include "Prerequisites only support Job, Pod"
      end

      it "allows static configuration" do
        role.first[:kind] = "ServiceAccount"
        role.first[:spec].delete(:template)
        role.first[:metadata][:annotations].delete(:"samson/prerequisite")
        refute errors
      end
    end

    describe "#validate_prerequisites_consistency" do
      before do
        role.first[:kind] = "Job"
        role.first[:metadata][:annotations] = {"samson/prerequisite": "true"}
        role.first[:spec][:template][:spec][:restartPolicy] = "Never"

        role.last[:kind] = "ConfigMap"
        role.last[:metadata][:annotations] = {"samson/prerequisite": "true"}
      end

      it "does not report consistent prerequisites values" do
        errors.must_equal nil
      end

      it "reports if prerequisites are inconsistent" do
        role.last[:metadata][:annotations] = {"samson/prerequisite": "false"}
        errors.must_include "Prerequisite annotation must be used consistently across all resources of each role"
      end

      it "reports when not all resources have prerequisites" do
        role.last[:metadata].delete(:annotations)
        errors.must_include "Prerequisite annotation must be used consistently across all resources of each role"
      end

      it "does not report if there are no prerequisites" do
        role.each { |r| r[:metadata][:annotations].delete(:"samson/prerequisite") }
        errors.must_equal nil
      end
    end

    describe 'pod' do
      let(:role) { pod_role }

      it "allows only Pod" do
        errors.must_equal nil
      end

      it "allows good containers" do
        role[0][:spec][:containers] << {
          name: "foo",
          resources: {requests: {cpu: "1m", memory: "1M"}, limits: {cpu: "1m", memory: "1M"}}
        }
        errors.must_equal nil
      end

      it "fails without containers" do
        role[0][:spec][:containers].clear
        errors.must_equal ["All templates need spec.containers"]
      end

      it "fails without container name" do
        role[0][:spec][:containers][0].delete :name
        errors.must_equal ["Containers need a name"]
      end

      it "fails without init container name" do
        role[0][:spec][:initContainers] = [{}]
        errors.first.must_equal "Containers need a name"
      end

      it "fails with missing requests" do
        role[0][:spec][:initContainers] = [{name: "foo"}]
        errors.must_equal [
          "Container foo is missing resources.requests.cpu",
          "Container foo is missing resources.requests.memory",
          "Container foo is missing resources.limits.cpu",
          "Container foo is missing resources.limits.memory"
        ]
      end

      it "allows missing resources on first container because it will be filled by samson" do
        role[0][:spec][:containers].delete :resources
      end

      it "fails with missing resources on second container" do
        role[0][:spec][:containers] << {name: "foo"}
        errors.must_equal [
          "Container foo is missing resources.requests.cpu",
          "Container foo is missing resources.requests.memory",
          "Container foo is missing resources.limits.cpu",
          "Container foo is missing resources.limits.memory"
        ]
      end
    end

    describe '#validate_job_restart_policy' do
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

      it "reports bad restart policy for CronJob" do
        role.replace(cron_job_role)
        role[0][:spec][:jobTemplate][:spec][:template][:spec][:restartPolicy] = 'Always'
        errors.must_equal ["CronJob spec.jobTemplate.spec.template.spec.restartPolicy must be one of Never/OnFailure"]
      end
    end

    describe '#validate_project_and_role_consistent' do
      let(:error_message) { "Project and role labels must be consistent across resources" }

      # this is not super important, but adding it for consistency
      it "reports missing job labels" do
        role.replace(job_role)
        role[0][:metadata][:labels].delete(:role)
        errors.must_equal [
          "Missing project or role for Job pi: metadata.labels",
          error_message
        ]
      end

      it "reports missing labels" do
        role.first[:spec][:template][:metadata][:labels].delete(:project)
        errors.must_equal [
          "Missing project or role for Deployment some-project-rc: spec.template.metadata.labels",
          error_message
        ]
      end

      it "allows cross-matching services when opted in" do
        role[1][:spec][:selector].delete(:role)
        role[1][:metadata][:annotations] = {"samson/service_selector_across_roles": "true"}
        errors.must_be_nil
      end

      it "reports missing label section" do
        role.first[:spec][:template][:metadata].delete(:labels)
        errors.must_equal [
          "Missing project or role for Deployment some-project-rc: spec.template.metadata.labels",
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

      it "reports deployments without selector, which would default to all labels (like team)" do
        role.first[:spec].delete :selector
        errors.must_equal [
          "Missing project or role for Deployment some-project-rc: spec.selector.matchLabels",
          error_message
        ]
      end
    end

    describe "#validate_host_volume_paths" do
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

    describe "#validate_not_matching_team" do
      it "reports bad selector" do
        role.last[:spec][:selector][:team] = 'foo'
        errors.to_s.must_include "Do not use spec.selector.team"
      end

      it "reports bad matchLabels" do
        role.first[:spec][:selector][:matchLabels][:team] = 'foo'
        errors.to_s.must_include "Do not use spec.selector.team"
      end
    end

    describe "#validate_daemon_set_supported" do
      before do
        role[0][:kind] = "DaemonSet"
        role[0][:apiVersion] = "apps/v1"
        role[0][:spec][:updateStrategy] = {type: "RollingUpdate", rollingUpdate: {maxUnavailable: "10%"}}
      end

      it "is valid" do
        errors.must_equal nil
      end

      it "complains about unsupported apiVersion" do
        role[0][:apiVersion] = "foo/v1"
        errors.must_equal ["set DaemonSet apiVersion to apps/v1"]
      end

      it "complains about unsupported strategy" do
        role[0][:spec][:updateStrategy] = {type: "OnDelete"}
        errors.must_equal ["set DaemonSet spec.updateStrategy.type to RollingUpdate"]
      end

      it "complains about unset maxUnavailable which will make the deploy timeout" do
        role[0][:spec][:updateStrategy].delete(:rollingUpdate)
        errors.to_s.must_include "default of 1"
      end
    end
  end

  describe '.map_attributes' do
    def call(path, elements)
      Kubernetes::RoleValidator.new(elements, project: nil).send(:map_attributes, path)
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

  describe '.validate_groups' do
    def validate_error(roles)
      Kubernetes::RoleValidator.validate_groups(roles)
    rescue Samson::Hooks::UserError
      $!.message
    end

    it "is valid with no role" do
      Kubernetes::RoleValidator.validate_groups([])
    end

    it "is valid with a single role" do
      Kubernetes::RoleValidator.validate_groups([[role.first]])
    end

    it "is valid with multiple different roles" do
      primary = role.first
      primary2 = primary.dup
      primary2[:metadata] = {labels: {role: "meh", project: primary.dig(:metadata, :labels, :project)}}
      Kubernetes::RoleValidator.validate_groups([[primary], [primary2]])
    end

    it "is valid with a duplicate role but magic annotation" do
      role.first[:metadata][:annotations] = {"samson/multi_project": "true"}
      Kubernetes::RoleValidator.validate_groups([[role.first], [role.first]])
    end

    it "is invalid with a duplicate role" do
      validate_error([[role.first], [role.first]]).
        must_equal "metadata.labels.role must be set and different in each role"
    end

    it "is invalid with different projects" do
      primary = role.first
      primary2 = primary.dup
      primary2[:metadata] = {labels: {role: "meh", project: "other"}}
      validate_error([[primary], [primary2]]).must_equal(
        "metadata.labels.project must be consistent but found [\"some-project\", \"other\"]"
      )
    end

    it "is invalid with different role labels in a single role" do
      primary = role.first
      primary2 = primary.dup
      primary2[:metadata] = {name: "bar", labels: {role: "meh", project: primary.dig(:metadata, :labels, :project)}}
      validate_error([[primary, primary2]]).must_equal(
        "metadata.labels.role must be set and consistent in each config file"
      )
    end

    it "is invalid when a role is not set" do
      primary = role.first
      primary2 = primary.dup
      primary2[:metadata] = {name: "bar", labels: {project: primary.dig(:metadata, :labels, :project)}}
      validate_error([[primary, primary2]]).must_equal(
        "metadata.labels.role must be set and consistent in each config file"
      )
    end

    it "is invalid when all role are not set" do
      primary = role.first
      primary[:metadata][:labels].delete :role
      validate_error([[primary]]).must_equal(
        "metadata.labels.role must be set and consistent in each config file"
      )
    end

    it "is invalid when using the same element twice" do
      validate_error([[role.first, role.first]]).must_equal "Deployment .some-project-rc exists multiple times"
    end
  end

  describe "#object_name" do
    empty = {}
    it "returns empty string if metadata is missing" do
      assert Kubernetes::RoleValidator.new([], project: nil).send(:object_name, empty) == ""
    end
  end
end
