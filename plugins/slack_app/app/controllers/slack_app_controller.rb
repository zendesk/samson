# frozen_string_literal: true
class SlackAppController < ApplicationController
  PUBLIC = [:command, :interact].freeze

  skip_before_action :verify_authenticity_token, :login_user, only: PUBLIC

  before_action :handle_slack_inputs

  def oauth
    @need_to_connect_app = app_token.nil?
    @need_to_connect_user = @current_user_from_slack.nil?
    @missing_configs = []
    @missing_configs << 'SLACK_CLIENT_ID' if ENV['SLACK_CLIENT_ID'].blank?
    @missing_configs << 'SLACK_CLIENT_SECRET' if ENV['SLACK_CLIENT_SECRET'].blank?
    @missing_configs << 'SLACK_VERIFICATION_TOKEN' if ENV['SLACK_VERIFICATION_TOKEN'].blank?

    if params[:code]
      # Got an OAuth code, let's fetch our tokens
      response = Faraday.post 'https://slack.com/api/oauth.access',
        client_id: ENV['SLACK_CLIENT_ID'],
        client_secret: ENV['SLACK_CLIENT_SECRET'],
        code: params[:code],
        redirect_uri: url_for(only_path: false)
      body = JSON.parse response.body

      if @need_to_connect_app
        SamsonSlackApp::SlackIdentifier.create!(identifier: body.fetch('access_token')).identifier
      end
      SamsonSlackApp::SlackIdentifier.create!(user_id: current_user.id, identifier: body.fetch('user_id'))

      redirect_to # to what ??
    end
  end

  def command
    render json: command_response
  end

  def interact
    render json: interact_response # This replaces the original message
  end

  private

  # TODO
  # - returning parts of the text can most likely be abused to do some kind of reflection attack.
  # - / is a bad separator between project and branch since branches often include / too
  def command_response
    return unknown_user_response unless @current_user_from_slack

    # Interesting parts of params:
    # {
    #   "user_id"=>"U0HAGH3AB", <-- look up Samson user using this
    #   "command"=>"/deploy",
    #   "text"=>"foobar/master to production", <-- deploy project foobar, branch master to stage production
    #   "response_url"=>"https://hooks.slack.com/commands/T0HAGP0J2/58604540277/g0xd4K2KOsgL9zXwR4kEc0eL"
    #    ^^^^ This is how to respond later, we can also directly return some JSON
    # }
    project_permalink, ref_name, stage_permalink =
      @payload['text'].match(/^([^\s\/]+)(?:\/(\S+))?(?: to (\S+))?$/)&.captures
    stage_permalink ||= 'production'
    ref_name ||= 'master'

    unless project_permalink
      return <<~TEXT
        Did not understand.
        Please use for example `project-permalink`, `project-permalink/branch`, `project-permalink to stage-permalink`.
      TEXT
    end

    unless project = Project.find_by_permalink(project_permalink)
      return "Could not find a project with permalink `#{project_permalink}`."
    end

    unless @current_user_from_slack.deployer_for?(project)
      return "You do not have permission to deploy on `#{project_permalink}`."
    end

    unless stage = project.stages.find_by_permalink(stage_permalink)
      return "`#{project_permalink}` does not have a stage `#{stage_permalink}`."
    end

    deploy_service = DeployService.new(@current_user_from_slack)
    deploy = deploy_service.deploy(stage, reference: ref_name)
    SamsonSlackApp::DeployResponseUrl.create! deploy: deploy, response_url: @payload[:response_url]

    SamsonSlackApp::SlackMessage.new(deploy).message_body
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
        text: unknown_user_response
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
    SamsonSlackApp::SlackMessage.new(deploy).message_body
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
      SamsonSlackApp::SlackIdentifier.find_by_user_id(current_user.id)&.user
    else
      slack_user_id = if @payload.key? 'user'
        @payload['user']['id']
      else
        @payload['user_id']
      end
      SamsonSlackApp::SlackIdentifier.find_by_identifier(slack_user_id)&.user
    end
  end

  def unknown_user_response
    "Visit #{url_for action: :oauth, only_path: false} to connect your accounts."
  end

  def app_token
    @app_token ||= SamsonSlackApp::SlackIdentifier.app_token
  end
end
