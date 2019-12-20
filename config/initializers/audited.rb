# frozen_string_literal: true

class << Audited
  def with_username(username)
    old = store[:audited_user]
    store[:audited_user] = username
    yield
  ensure
    store[:audited_user] = old
  end
end
