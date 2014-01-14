class Warden::Strategies::SessionStrategy < Warden::Strategies::Base
  def valid?
    true
  end

  def authenticate!
    redirect!('/login')
  end
end

Warden::Strategies.add(:session, Warden::Strategies::SessionStrategy)
