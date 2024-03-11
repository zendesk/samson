# frozen_string_literal: true
require_relative '../test_helper'

SingleCov.covered!

describe DatadogDeployEvent do
  let(:deploy) { deploys(:succeeded_test) }

  describe '.deliver' do
    def deliver(**args)
      DatadogDeployEvent.deliver(deploy, **args)
    end

    def expected_body(overrides = {})
      {
        title: 'Super Admin deployed staging to Staging',
        text: 'super-admin@example.com deployed staging to Staging',
        alert_type: 'success',
        source_type_name: 'samson',
        date_happened: happened.to_i,
        tags: ['deploy']
      }.merge(overrides).to_json
    end

    let(:url) { 'https://api.datadoghq.com/api/v1/events?api_key=dapikey' }
    let(:happened) { Time.at(1388607000) }

    it 'delivers correct event with deploy updated_at' do
      assert_request(:post, url, with: {body: expected_body}) do
        deliver(tags: [], time: happened)
      end
    end

    it 'delivers correct event with additional tags' do
      assert_request(:post, url, with: {body: expected_body(tags: ['one', 'two', 'deploy'])}) do
        deliver(tags: ['one', 'two'], time: happened)
      end
    end

    it 'delivers info event if deploy is in progress' do
      deploy.job.update_column(:status, 'running')

      expected_values = {
        alert_type: 'info',
        title: 'Super Admin is deploying staging to Staging'
      }

      assert_request(:post, url, with: {body: expected_body(expected_values)}) do
        deliver(tags: [], time: happened)
      end
    end

    it 'delivers error event if deploy did not succeed' do
      deploy.job.update_column(:status, 'failed')

      expected_values = {
        alert_type: 'error',
        title: 'Super Admin failed to deploy staging to Staging'
      }
      assert_request(:post, url, with: {body: expected_body(expected_values)}) do
        deliver(tags: [], time: happened)
      end
    end

    it 'logs success message if status is 202' do
      assert_request(:post, url, with: {body: expected_body}, to_return: {status: 202}) do
        deliver(tags: [], time: happened)
      end
    end

    it 'logs failure message if status is not 202' do
      Samson::ErrorNotifier.expects(:notify)
      assert_request(:post, url, with: {body: expected_body}, to_return: {status: 400}) do
        deliver(tags: [], time: happened)
      end
    end

    it "notifies of errors but does not block deploys when datadog is unreachable" do
      Samson::ErrorNotifier.expects(:notify)
      assert_request(:post, url, with: {body: expected_body}, to_timeout: []) do
        deliver(tags: [], time: happened)
      end
    end

    it "can notify about kubernetes project/role/team" do
      expected_values = {tags: ["deploy", "kube_project:foo", "team:foo"]}

      deploy.kubernetes = true
      doc = Kubernetes::ReleaseDoc.new
      doc.send(:resource_template=, [{metadata: {labels: {project: "foo", role: "bar", team: "baz"}}}])
      deploy.stubs(:kubernetes_release).returns Kubernetes::Release.new(release_docs: [doc])

      assert_request(:post, url, with: {body: expected_body(expected_values)}) do
        deliver(tags: [], time: happened)
      end
    end
  end
end
