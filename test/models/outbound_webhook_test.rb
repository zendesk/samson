# frozen_string_literal: true
require_relative '../test_helper'

SingleCov.covered!

describe OutboundWebhook do
  let(:webhook_attributes) { {url: "https://testing.com/deploys", auth_type: "None"} }
  let(:webhook) { OutboundWebhook.new(webhook_attributes) }

  describe '#validations' do
    it 'is valid' do
      assert_valid webhook
    end

    it "validates that url begins with http:// or https://" do
      webhook.url = "/foobar"
      refute_valid webhook
    end

    it "validates user+password for basic auth" do
      webhook.auth_type = "Basic"
      refute_valid webhook

      webhook.username = "U"
      refute_valid webhook

      webhook.password = "P"
      assert_valid webhook
    end

    it "validates password for token auth" do
      webhook.auth_type = "Token"
      refute_valid webhook

      webhook.password = "P"
      assert_valid webhook
    end

    it "validates auth type" do
      webhook.auth_type = "Wut"
      refute_valid webhook
    end

    it "needs a name when global" do
      webhook.global = true
      refute_valid webhook, :name
    end

    it "allows multiple blank names" do
      webhook.name = ""
      webhook.save!
      OutboundWebhook.create!(webhook_attributes.merge(name: ""))
    end

    it "does not allow names for non-global since that leads to duplication" do
      webhook.name = "foo"
      refute_valid webhook, :name
    end
  end

  describe "#ssl?" do
    it "is ssl with https" do
      assert webhook.ssl?
    end

    it "is not ssl with http" do
      webhook.url = "http://sdfsf.com"
      refute webhook.ssl?
    end

    it "is not ssl with insecure" do
      webhook.insecure = true
      refute webhook.ssl?
    end
  end

  describe "#ensure_unused" do
    it "allows deletion when unused" do
      webhook.save!
      webhook.destroy!
    end

    it "does not allow deletion when used" do
      webhook.save!
      webhook.stages = [stages(:test_staging)]
      refute webhook.destroy
    end
  end

  describe "#connection" do
    let(:connection) { webhook.send(:connection) }

    it "does not add auth when not configured" do
      refute_includes connection.headers, 'Authorization'
    end

    it "adds basic auth" do
      webhook.auth_type = "Basic"
      webhook.username = "adminuser"
      webhook.password = "abc123"
      assert_equal connection.headers['Authorization'], 'Basic YWRtaW51c2VyOmFiYzEyMw=='
    end

    it "adds token auth" do
      webhook.auth_type = "Token"
      webhook.username = "adminuser"
      webhook.password = "abc123"
      assert_equal connection.headers['Authorization'], 'Token abc123'
    end

    it "fails on unsupported type" do
      webhook.auth_type = "Wut"
      assert_raises(ArgumentError) { connection }
    end
  end

  describe "#deliver" do
    let(:webhook) { OutboundWebhook.create!(webhook_attributes) }
    let(:deploy) { deploys(:succeeded_test) }
    let(:output) { StringIO.new }

    # Make sure most paths don't sleep unexpectedly
    before do
      webhook.unstub(:sleep)
      webhook.expects(:sleep).with { raise "Unexpected sleep poll" }.never
    end

    it "posts" do
      assert_request :post, "https://testing.com/deploys" do
        webhook.deliver(deploy, output)
      end
      output.string.must_equal <<~TEXT
        Webhook notification: sending to https://testing.com/deploys ...
        Webhook notification: succeeded
      TEXT
    end

    it "fails on bad response" do
      e = assert_raises Samson::Hooks::UserError do
        assert_request :post, "https://testing.com/deploys", to_return: {status: 400, body: "a" * 200} do
          webhook.deliver(deploy, output)
        end
      end
      output.string.must_equal "Webhook notification: sending to https://testing.com/deploys ...\n"

      # this will go into the job-execution log via the error catcher
      e.message.must_equal <<~TEXT.rstrip
        Webhook notification: failed 400
        aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa...
      TEXT
    end

    it "fails on internal error" do
      e = assert_raises Samson::Hooks::UserError do
        assert_request :post, "https://testing.com/deploys", to_timeout: [] do
          webhook.deliver(deploy, output)
        end
      end
      e.message.must_equal "Webhook notification: failed Faraday::ConnectionFailed"
      output.string.must_equal "Webhook notification: sending to https://testing.com/deploys ...\n"
    end

    describe "status_path" do
      def assert_webhook_fired(&block)
        assert_request :post, "https://testing.com/deploys", to_return: polling_target, &block
      end

      with_env OUTBOUND_WEBHOOK_POLL_PERIOD: '1'

      let(:polling_target) { {body: {foo: "http://foo.com/bar"}.to_json} }

      before { webhook.status_path = 'foo' }

      it "polls status url until it succeeds" do
        replies = [
          {status: 202, body: "HELLO"},
          {status: 202, body: "WORLD"},
          {status: 200, body: "DONE"}
        ]
        assert_webhook_fired do
          webhook.unstub(:sleep)
          webhook.expects(:sleep).with(1).times(2)
          assert_request :get, "http://foo.com/bar", to_return: replies do
            webhook.deliver(deploy, output)
          end
        end
        output.string.must_equal <<~TEXT
          Webhook notification: sending to https://testing.com/deploys ...
          Webhook notification: polling http://foo.com/bar ...
          Webhook notification: HELLO
          Webhook notification: WORLD
          Webhook notification: DONE
          Webhook notification: succeeded
        TEXT
      end

      it "fails on non successful status code" do
        e = assert_raises Samson::Hooks::UserError do
          assert_webhook_fired do
            assert_request :get, "http://foo.com/bar", to_return: {status: 500, body: "SERVER_ERROR"} do
              webhook.deliver(deploy, output)
            end
          end
        end
        e.message.must_equal "error polling status endpoint"
        output.string.must_equal <<~TEXT
          Webhook notification: sending to https://testing.com/deploys ...
          Webhook notification: polling http://foo.com/bar ...
          Webhook notification: SERVER_ERROR
        TEXT
      end

      it "fails on parse error" do
        polling_target[:body] = "<html>wtf</html>"
        e = assert_raises Samson::Hooks::UserError do
          assert_webhook_fired do
            webhook.deliver(deploy, output)
          end
        end
        e.message.must_equal "Webhook notification: failed JSON::ParserError"
        output.string.must_equal <<~TEXT
          Webhook notification: sending to https://testing.com/deploys ...
        TEXT
      end

      it "fails when status url is missing" do
        polling_target[:body] = "{}"
        e = assert_raises Samson::Hooks::UserError do
          assert_webhook_fired do
            webhook.deliver(deploy, output)
          end
        end
        e.message.must_equal "Webhook notification: response did not include status url at foo"
        output.string.must_equal <<~TEXT
          Webhook notification: sending to https://testing.com/deploys ...
        TEXT
      end

      it "fails when status polling fails" do
        e = assert_raises Samson::Hooks::UserError do
          assert_webhook_fired do
            assert_request :get, "http://foo.com/bar", to_timeout: [] do
              webhook.deliver(deploy, output)
            end
          end
        end
        e.message.must_equal "Webhook notification: failed Faraday::ConnectionFailed"
        output.string.must_equal <<~TEXT
          Webhook notification: sending to https://testing.com/deploys ...
          Webhook notification: polling http://foo.com/bar ...
        TEXT
      end
    end
  end

  describe "#as_json" do
    it "does not show password" do
      webhook.password = '123'
      webhook.as_json.keys.wont_include 'password'
    end
  end

  describe ".deploy_as_json" do
    it "renders a deploy" do
      json = OutboundWebhook.deploy_as_json(deploys(:succeeded_test))
      json.keys.must_include 'id'
      json.keys.must_include 'user'
      json.keys.must_include 'project'
      json.keys.must_include 'stage'
      json.keys.must_include 'deploy_groups'
    end
  end

  describe '.active' do
    it 'returns only active webhooks' do
      active_webhook = OutboundWebhook.create!(webhook_attributes)
      OutboundWebhook.create!(webhook_attributes.merge(disabled: true))
      OutboundWebhook.active.must_equal([active_webhook])
    end
  end
end
