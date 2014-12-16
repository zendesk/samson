require 'radar_client_rb'
require 'redis'

if ENV.has_key?('ENABLE_RADAR')
  Radar::Client.define_redis_retriever do |subdomain|
    Redis.new(:host => ENV['RADAR_HOST'], :port => ENV['REDIS_PORT'])
  end
end
