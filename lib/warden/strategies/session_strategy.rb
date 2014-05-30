class Warden::Strategies::SessionStrategy < Warden::Strategies::Base
  def valid?
    true
  end

  def authenticate!
    redirect!('/login', origin: request.path)
  end
end

Warden::Strategies.add(:session, Warden::Strategies::SessionStrategy)
