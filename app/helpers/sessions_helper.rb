module SessionsHelper
  def omniauth_path(type)
    "/auth/#{type}?origin=#{CGI.escape(params.fetch(:origin, '/'))}"
  end
end
