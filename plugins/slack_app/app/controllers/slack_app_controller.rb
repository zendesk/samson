# frozen_string_literal: true
class SlackAppController < ApplicationController
  PUBLIC = [:command, :interact].freeze
  skip_before_action :verify_authenticity_token, :login_user, only: PUBLIC

  before_action :handle_slack_inputs

  def oauth
    @need_to_connect_app = app_token.nil?
    @need_to_connect_user = @current_user_from_slack.nil?
    @missing_configs = []
    @missing_configs << 'SLACK_CLIENT_ID' unless ENV['SLACK_CLIENT_ID'].present?
    @missing_configs << 'SLACK_CLIENT_SECRET' unless ENV['SLACK_CLIENT_SECRET'].present?
    @missing_configs << 'SLACK_VERIFICATION_TOKEN' unless ENV['SLACK_VERIFICATION_TOKEN'].present?

    if params[:code]
      # Got an OAuth code, let's fetch our tokens
      response = Faraday.post 'https://slack.com/api/oauth.access',
        client_id: ENV['SLACK_CLIENT_ID'],
        client_secret: ENV['SLACK_CLIENT_SECRET'],
        code: params[:code],
        redirect_uri: url_for(only_path: false)
      body = JSON.parse response.body

      if @need_to_connect_app
        SlackIdentifier.create!(identifier: body.fetch('access_token')).identifier
      end
      SlackIdentifier.create!(user_id: current_user.id, identifier: body.fetch('user_id'))

      redirect_to
    end
  end

  def command
    render json: command_response
  end

  def interact
    render json: interact_response # This replaces the original message
  end

  private

  def command_response
    # Interesting parts of params:
    # {
    #   "user_id"=>"U0HAGH3AB", <-- look up Samson user using this
    #   "command"=>"/deploy",
    #   "text"=>"foo bar baz", <-- this is what to deploy
    #   "response_url"=>"https://hooks.slack.com/commands/T0HAGP0J2/58604540277/g0xd4K2KOsgL9zXwR4kEc0eL"
    #    ^^^^ This is how to respond later, we can also directly return some JSON
    # }
    return unknown_user unless @current_user_from_slack

    # Parse the command
    project_name, ref_name, stage_name = @payload['text'].match(/([^\s\/]+)(?:\/(\S+))?\s*(?:to\s+(.*))?/).captures

    # Sanity checks
    unless project = Project.find_by_permalink(project_name)
      return unknown_project(project_name)
    end

    return unauthorized_deployer(project) unless @current_user_from_slack.deployer_for?(project)

    stage = project.stages.find_by_permalink(stage_name || 'production')
    return unknown_stage(project, stage_name) unless stage.present?

    deploy_service = DeployService.new(@current_user_from_slack)
    deploy = deploy_service.deploy(stage, reference: ref_name || 'master')
    DeployResponseUrl.create! deploy: deploy, response_url: @payload[:response_url]

    SlackMessage.new(deploy).message_body
  end

  def interact_response
    # Interesting parts of the payload:
    # {
    #   "actions"=>[
    #     {"name"=>"one", "value"=>"one"} <-- which button the user clicked
    #   ],
    #   "callback_id"=>"123456", <-- maps to a deployment
    #   "user"=>{"id"=>"U0HAGH3AB", "name"=>"ben"}, <-- who clicked
    #   "action_ts"=>"1468259216.482422",
    #   "message_ts"=>"1468259019.000006", <-- need this to maybe update the message
    #   "response_url"=>"https://hooks.slack.com/actions/T0HAGP0J2/58691408951/iHdjN2zjX0dZ5rXyl84Otql7"
    #    ^^^^ This is how to respond later, we can also directly return some JSON
    # }

    # This means someone clicked the "Approve" button in the channel
    deploy = Deploy.find_by_id @payload['callback_id']
    return '_(Unable to locate this deploy.)_' unless deploy

    # Is this user connected?
    unless @current_user_from_slack
      return {
        replace_original: false,
        text: unknown_user
      }
    end

    # Can this user approve the deployment?
    if @current_user_from_slack == deploy.user
      return {
        replace_original: false,
        text: "You cannot approve your own deploys."
      }
    end
    unless @current_user_from_slack.deployer_for?(deploy)
      return {
        replace_original: false,
        text: "You do not have permissions to approve that deploy."
      }
    end

    # Buddy up
    deploy.confirm_buddy!(@current_user_from_slack)
    SlackMessage.new(deploy).message_body
  end

  def unknown_user
    "You're not set up to use this yet. Please visit " \
    "#{url_for action: :oauth, only_path: false} " \
    "to connect your accounts."
  end

  def unknown_project(project)
    "Couldn't find a project with permalink `#{project}`."
  end

  def unknown_stage(project, stage_name)
    "Sorry, " \
    "<#{project_path(project)}|#{project.name}> " \
    "doesn't have a stage named `#{stage_name}`."
  end

  def unauthorized_deployer(project)
    "Sorry, it doesn't look like you have permission to create a deployment on `#{project}`."
  end

  def handle_slack_inputs
    if params[:ssl_check]
      # Slack does this when you're configuring your application
      return render json: 'ok'
    end

    @payload = (params[:payload] ? JSON.parse(params[:payload]) : params)
    token = @payload['token'].presence
    if token && !ActiveSupport::SecurityUtils.secure_compare(token, ENV['SLACK_VERIFICATION_TOKEN'] || '')
      raise "Slack token doesn't match SLACK_VERIFICATION_TOKEN"
    end

    @current_user_from_slack = if current_user
      SlackIdentifier.find_by_user_id(current_user.id)&.user
    else
      slack_user_id = if @payload.key? 'user'
        @payload['user']['id']
      else
        @payload['user_id']
      end
      SlackIdentifier.find_by_identifier(slack_user_id)&.user
    end
  end

  def app_token
    @app_token ||= SlackIdentifier.app_token
  end
end
