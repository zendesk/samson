require 'json'
require 'http'
module Kubeclient
  module Common
    # HTTP Stream used to watch changes on entities
    class WatchStream
      def initialize(uri, http_options, format: :json)
        @uri = uri
        @http_client = nil
        @http_options = http_options
        @format = format
      end

      def each
        @finished = false

        @http_client = build_client
        response = @http_client.request(:get, @uri, build_client_options)
        unless response.code < 300
          fail KubeException.new(response.code, response.reason, response)
        end

        buffer = ''
        response.body.each do |chunk|
          buffer << chunk
          while (line = buffer.slice!(/.+\n/))
            yield @format == :json ? WatchNotice.new(JSON.parse(line)) : line.chomp
          end
        end
      rescue IOError
        raise unless @finished
      end

      def finish
        @finished = true
        @http_client.close unless @http_client.nil?
      end

      private

      def build_client
        if @http_options[:basic_auth_user] && @http_options[:basic_auth_password]
          HTTP.basic_auth(user: @http_options[:basic_auth_user],
                          pass: @http_options[:basic_auth_password])
        else
          HTTP::Client.new
        end
      end

      def build_client_options
        client_options = { headers: @http_options[:headers] }
        if @http_options[:ssl]
          client_options[:ssl] = @http_options[:ssl]
          client_options[:ssl_socket_class] =
              @http_options[:ssl_socket_class] if @http_options[:ssl_socket_class]
        else
          client_options[:socket_class] =
              @http_options[:socket_class] if @http_options[:socket_class]
        end
        client_options
      end
    end
  end
end
