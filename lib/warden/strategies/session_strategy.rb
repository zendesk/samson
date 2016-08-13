# frozen_string_literal: true
class Warden::Strategies::SessionStrategy < Warden::Strategies::Base
  def valid?
    true
  end

  def authenticate!
    if request.content_type == 'application/json'
      throw(:warden)
    else
      redirect!('/login'.dup, origin: request.path)
    end
  end
end

Warden::Strategies.add(:session, Warden::Strategies::SessionStrategy)
