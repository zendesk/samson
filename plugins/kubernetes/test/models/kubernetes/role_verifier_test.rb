require_relative "../../test_helper"

SingleCov.covered!

describe Kubernetes::RoleVerifier do
  describe '.verify' do
    let(:role) do
      [
        {
          kind: 'Deployment',
          metadata: {name: 'foobar'},
          spec: {
            selector: {
              matchLabels: {
                project: 'foo',
                role: 'bar'
              }
            },
            template: {
              metadata: {
                labels: {
                  project: 'foo',
                  role: 'bar'
                }
              },
              spec: {
                containers: [{}]
              }
            }
          }
        },
        {
          kind: 'Service',
          metadata: {
            name: 'foobar'
          },
          spec: {
            selector: {
              project: 'foo',
              role: 'bar'
            }
          }
        }
      ]
    end
    let(:job_role) do
      # http://kubernetes.io/docs/user-guide/jobs/
      [YAML.load(<<-YAML).with_indifferent_access]
        apiVersion: batch/v1
        kind: Job
        metadata:
          labels:
            project: foo
            role: bar
          name: pi
        spec:
          template:
            metadata:
              labels:
                project: foo
                role: bar
            spec:
              containers:
              - name: pi
                image: perl
                command: ["perl"]
              restartPolicy: Never
      YAML
    end
    let(:role_json) { role.to_json }
    let(:errors) { Kubernetes::RoleVerifier.new(role_json).verify }

    it "works" do
      errors.must_equal nil
    end

    it "fails nicely with empty template" do
      role_json.replace "{}"
      refute errors.empty?
    end

    it "fails nicely with borked template" do
      role_json.replace "---"
      refute errors.empty?
    end

    it "reports invalid json" do
      role_json.replace "{oops"
      errors.must_equal ["Unable to parse role definition"]
    end

    it "reports invalid yaml" do
      role_json.replace "}foobar:::::"
      errors.must_equal ["Unable to parse role definition"]
    end

    it "reports invalid types" do
      role.first[:kind] = "Ohno"
      errors.must_include "Did not include supported kinds: Deployment, DaemonSet, Job"
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
      errors.must_include "Can only have maximum of 1 Service"
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
      errors.must_equal ["Only 1 item of type Deployment/DaemonSet/Job is supported per role"]
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
      let(:error_message) { "Project and role labels must be consistent accross Deployment/DaemonSet/Service/Job" }

      # this is not super important, but adding it for consistency
      it "reports missing job labels" do
        role.replace(job_role)
        role[0][:metadata][:labels].delete(:role)
        errors.must_include error_message
      end

      it "reports missing labels" do
        role.first[:spec][:template][:metadata][:labels].delete(:project)
        errors.must_include error_message
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
