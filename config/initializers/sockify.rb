# frozen_string_literal: true
#
# TODO: remove one `rails runner 'Rails.cache.fetch 1'` works with memcached
# dalli has this code inside an `if RUBY_VERSION >= '3.0'` but only old version works
require 'dalli'

class Dalli::Socket::TCP
  def self.open(host, port, options = {})
    Timeout.timeout(options[:socket_timeout]) do
      sock = new(host, port)
      sock.options = {host: host, port: port}.merge(options)
      init_socket_options(sock, options)

      options[:ssl_context] ? wrapping_ssl_socket(sock, host, options[:ssl_context]) : sock
    end
  end
end
