# frozen_string_literal: true
require_relative '../../test_helper'

SingleCov.covered!

describe ApplicationCable::Connection do
  let(:user) { users(:viewer) }
  let(:env) { {'warden' => stub("Warden", user: user)} }
  let(:server) do
    stub("Server", worker_pool: nil, logger: Rails.logger, config: stub("Config", log_tags: []), event_loop: nil)
  end
  let(:connection) { ApplicationCable::Connection.new(server, env) }

  describe "#connect" do
    it "connects with user" do
      connection.connect
      connection.current_user.must_equal user
    end

    it "fails without user" do
      env['warden'].stubs(user: nil)
      assert_raises ActionCable::Connection::Authorization::UnauthorizedError do
        connection.connect
      end
    end
  end
end
