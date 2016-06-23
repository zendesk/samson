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
      errors.must_include "Did not include supported kinds: Deployment, DaemonSet"
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
      errors.must_include "Deployment and DaemonSet need at least 1 container"
    end

    describe 'inconsistent labels' do
      let(:error_message) { "Project and role labels must be consistent accross Deployment/DaemonSet/Service" }

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
