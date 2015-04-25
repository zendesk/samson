require_relative "../../test_helper"

describe SamsonServerLogs::KafkaListener do
  let(:output) { OutputBuffer.new }
  let(:deploy_id) { 123 }
  let(:listener) { SamsonServerLogs::KafkaListener.new(deploy_id, output) }
  let(:kafka) do
    Class.new do
      attr_accessor :messages
      def fetch(*args)
        sleep 0.1
        [*messages.shift].map { |v| OpenStruct.new(value: v) }
      end
    end.new.tap { |k| k.messages = [] }
  end

  def server_deployed
    output.write('uploading deploy logs: foobar servers: ["server_a", "server_b"]')
  end

  def send_message_after(time, message)
    Thread.new do
      sleep time
      kafka.messages << message.to_json
    end
  end

  def server_done(time, name)
    send_message_after time, deploy: deploy_id, exit: 0, host: name
  end

  def server_failed(time, name)
    send_message_after time, deploy: deploy_id, exit: 1, host: name
  end

  def assert_time(operator, delta, &block)
    time = Benchmark.realtime(&block)
    assert_operator time, operator, delta
  end

  before do
    Poseidon::PartitionConsumer.stubs(:new).returns(kafka)
    SamsonServerLogs::KafkaListener.total_timeout = 1.second
    SamsonServerLogs::KafkaListener.deploy_timeout = 1.second
  end

  describe "#listen" do
    it "listens and stops when all servers are done" do
      server_done 0.2, "server_a"
      server_done 0.4, "server_b"

      success = listener.listen do
        server_deployed
        sleep 0.1
        true
      end
      success.must_equal true
    end

    it "marks a deploy as failed when not all servers respond" do
      server_done 0.2, "server_a"

      success = listener.listen do
        server_deployed
        sleep 0.1
        true
      end
      success.must_equal false
    end

    it "marks a deploy as failed when server responds with failure" do
      server_done 0.2, "server_a"
      server_failed 0.4, "server_b"

      assert_time :<, 0.8 do
        success = listener.listen do
          server_deployed
          sleep 0.1
          true
        end
        success.must_equal false
      end
    end

    it "marks a deploy as failed when the deploy failed" do
      server_done 0.2, "server_a"
      server_done 0.4, "server_b"

      success = listener.listen do
        server_deployed
        sleep 0.1
        false
      end
      success.must_equal false
    end
  end

  describe "#listen_for_server_list" do
    let!(:thread) { Thread.new { listener.send(:listen_for_server_list) } }
    let(:servers) { listener.instance_variable_get(:@waiting_for_servers) }

    after { thread.kill }

    it "is alive when nothing happended" do
      thread.alive?.must_equal true
      servers.must_equal nil
    end

    it "does not stop when unrecognized message is received" do
      output.write "random message"
      sleep 0.01
      thread.alive?.must_equal true
      servers.must_equal nil
    end

    it "stops when correct message is received" do
      server_deployed
      sleep 0.01
      thread.alive?.must_equal false
      servers.must_equal ["server_a", "server_b"]
    end
  end

  describe "#listen_to_kafka" do
    let(:output) { StringIO.new }
    let!(:thread) { Thread.new { listener.send(:listen_to_kafka) } }

    def set_var(name, value)
      listener.instance_variable_set(:"@#{name}", value)
    end

    def get_var(name)
      listener.instance_variable_get(:"@#{name}")
    end

    before { set_var(:print, :all) }

    it "prints all buffered and then all new messages" do
      send_message_after 0, deploy: deploy_id, message: "a"
      sleep 0.15
      output.string.must_equal "Kafka: {\"deploy\"=>123, \"message\"=>\"a\"}\n"

      # each new message is auto-flushed
      send_message_after 0, deploy: deploy_id, message: "b"
      sleep 0.15
      output.string.must_equal "Kafka: {\"deploy\"=>123, \"message\"=>\"a\"}\nKafka: {\"deploy\"=>123, \"message\"=>\"b\"}\n"
    end

    it "does not print while waiting for deploy to finish" do
      set_var :print, false
      send_message_after 0, deploy: deploy_id, message: "a"
      sleep 0.15
      output.string.must_equal ""
    end

    it "does not print other deploys" do
      send_message_after 0, deploy: deploy_id+1, message: "a"
      sleep 0.15
      output.string.must_equal ""
    end

    it "removes servers that were recieved" do
      set_var :waiting_for_servers, ["server_a"]
      server_done(0, "server_a")
      sleep 0.15
      get_var(:waiting_for_servers).must_equal []
    end

    it "removes servers that were recieved earlier" do
      server_done(0, "server_a")
      sleep 0.15
      set_var :waiting_for_servers, ["server_a"]
      sleep 0.15
      get_var(:waiting_for_servers).must_equal []
    end
  end
end
