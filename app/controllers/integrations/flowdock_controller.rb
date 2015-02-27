require 'flowdock'

module Integrations
  class FlowdockController < Integrations::BaseController
    before_action :find_deploy, only: [:notify]

    def users
      users = Rails.cache.fetch(:flowdock_users, expires_in: 5.minutes, race_condition_ttl: 5) { flowdock_users }
      render json: { users: users }
    end

    def notify
      FlowdockNotification.new(@deploy.stage, @deploy).buddy_request(params[:message])
      render json: { message: 'Successfully sent a buddy request to the flows!' }
    end

    private

    def flowdock_users
      flowdock_client.get('/users').map do |user|
        {
          id: user['id'],
          name: user['nick'],
          avatar: user['avatar'],
          type: user['contact']
        }
      end
    end

    def flowdock_client
      @flowdock_client || ::Flowdock::Client.new(api_token: ENV['FLOWDOCK_API_TOKEN'])
    end

    def find_deploy
      @deploy = Deploy.find(params[:deploy_id])
    rescue ActiveRecord::RecordNotFound
      render status: 404, json: { message: 'Could not find stage' }
    end

  end
end
