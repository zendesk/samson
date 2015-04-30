require 'poseidon'
require 'open-uri'
require 'json'

module SamsonServerLogs
  class KafkaListener
    cattr_accessor(:total_timeout, instance_accessor: false) { 30.minute }
    cattr_accessor(:deploy_timeout, instance_accessor: false) { 10.minute }
    KAFKA_TOPIC = ENV["KAFKA_TOPIC"] || "samson_deploy"

    def initialize(deploy_id, output)
      @deploy_id = deploy_id
      @output = output
      @consumer = Poseidon::PartitionConsumer.new(
        "samson_deploy_listener",
        *kafka_url_and_port, KAFKA_TOPIC, 0, :latest_offset
      )
      @timeout = self.class.total_timeout.from_now
      @waiting_for_servers = nil
      @print = false
    end

    def listen
      kafka = Thread.new { listen_to_kafka }
      Thread.new { listen_for_server_list }

      deploy_success = yield

      # no servers found during deploy ?
      unless @waiting_for_servers
        kafka.kill
        @stop_listen_for_server_list = true
        write "did not find any servers in deploy log"
        return false
      end

      # wait for this time after the deploy is done
      @timeout = self.class.deploy_timeout.from_now
      @print = :all

      return false unless kafka.value

      deploy_success
    end

    private

    # listen for the line that tells us which servers we actually deploy to
    def listen_for_server_list
      @output.each do |_, message|
        break if @stop_listen_for_server_list
        if servers = message[/uploading deploy logs: \S+ servers: (\[.*?\])/i, 1]
          @waiting_for_servers = JSON.load(servers)
          break
        end
      end
    end

    def listen_to_kafka
      messages = []
      done_servers = []
      failed_servers = []

      loop do
        received = listen_for_messages(messages)

        print = decide_what_to_print(received, messages)
        print.each { |m| write m }


        print.select { |m| m["exit"] }.each do |m|
          type = (m["exit"] == 0 ? done_servers : failed_servers)
          type << m["host"]
        end

        # stop when we timeout or all servers are done
        if Time.now > @timeout
          write "listener timed out"
          return false
        elsif @waiting_for_servers
          @waiting_for_servers -= done_servers
          @waiting_for_servers -= failed_servers

          if @waiting_for_servers.empty?
            write "received messages from all hosts: success (#{done_servers.join(", ")} -- failure (#{failed_servers.join(", ")})"
            return failed_servers.empty?
          end
        end
      end
    end

    def write(message)
      @output.write("Kafka: #{message}\n")
    end

    # start printing after the deploy is done, and then print everything as it comes in
    def decide_what_to_print(received, messages)
      case @print
      when :all
        @print = :new
        messages
      when :new
        received
      else
        []
      end
    end

    # listen for all messages for the current deploy
    def listen_for_messages(messages)
      received = @consumer.fetch(max_wait_ms: 100).map! { |m| JSON.load(m.value) }
      received.select! { |m| m["deploy"] == @deploy_id }
      messages.concat received
      received
    end

    def kafka_url_and_port
      @kafka_url_and_port ||= if host = ENV["KAFKA_HOST"]
        [host, ENV.fetch("KAFKA_PORT", 9092).to_i]
      else
        consul = ENV.fetch("CONSUL_URL", "http://localhost:8500")
        url = "#{consul}/v1/health/service/#{ENV.fetch("KAFKA_SERVICE_NAME", "kafka")}?passing=1"
        server = JSON.load(open(url).read).first
        ["#{server.fetch("Node").fetch("Node")}", server.fetch("Service").fetch("Port")]
      end
    end
  end
end
