# frozen_string_literal: true
module SessionsHelper
  def omniauth_path(type)
    origin = params[:redirect_to] || "/" # set by unauthorized_controller.rb
    raise ArgumentError, "Hackers from #{origin} ?" unless origin.start_with?("/")
    "/auth/#{type}?origin=#{CGI.escape(origin)}"
  end
end
