require 'celluloid/current'
require 'celluloid/io'
require 'kubeclient'
require 'http'
require 'json'
require 'logger'

# monkey patching kubeclient to use non-blocking IO in watch streams
module Kubeclient
  module Common
    class WatchStream
      def each(&block)
        @finished = false
        @http = get_client
        response = @http.request(:get, @uri, build_client_options)
        unless response.code < 300
          fail KubeException.new(response.code, response.reason, response)
        end
        read_stream(response.body, &block)
      rescue IOError
        raise unless @finished
      end

      def finish
        @finished = true
        @http.close unless @http.nil?
      end

      private

      def get_client
        if !@http_options[:use_ssl] && @http_options[:basic_auth_user] && @http_options[:basic_auth_password]
          HTTP.basic_auth(user: @http_options[:basic_auth_user], pass: @http_options[:basic_auth_password])
        else
          HTTP::Client.new
        end
      end

      def build_client_options
        if @http_options[:use_ssl]
          ctx = OpenSSL::SSL::SSLContext.new
          ctx.cert = @http_options[:cert]
          ctx.key = @http_options[:key]
          ctx.ca_file = @http_options[:ca_file]
          ctx.cert_store = @http_options[:cert_store]
          ctx.verify_mode = @http_options[:verify_mode]
          { ssl_context: ctx, ssl_socket_class: Celluloid::IO::SSLSocket }
        else
          { socket_class: Celluloid::IO::TCPSocket }
        end
      end

      def read_stream(response_body)
        buffer = ''
        response_body.each do |chunk|
          buffer << chunk
          while (line = buffer.slice!(/.+\n/))
            yield @format == :json ? WatchNotice.new(JSON.parse(line)) : line.chomp
          end
        end
      end
    end
  end

  class Client
    NEW_ENTITY_TYPES = %w(Deployment).map do |et|
      clazz = Class.new(RecursiveOpenStruct) do
        def initialize(hash = nil, args = {})
          args.merge!(recurse_over_arrays: true)
          super(hash, args)
        end
      end
      [Kubeclient.const_set(et, clazz), et]
    end
    ClientMixin.define_entity_methods(NEW_ENTITY_TYPES)
    ENTITY_TYPES.concat NEW_ENTITY_TYPES
  end
end

Celluloid.logger = Rails.logger
$CELLULOID_DEBUG = true

if ENV['SERVER_MODE'] && !ENV['PRECOMPILE']
  Kubernetes::Cluster.all.each { |cluster| Watchers::ClusterPodWatcher::start_watcher(cluster) }
end
