Deploy.class_eval do
  def default_flowdock_message(user)
    ":pray: #{user_tag(user)} is requesting approval for deploy #{url}"
  end

  private

  def user_tag(user)
    "@#{user.email.match(/(.*)@/)[1]}"
  end
end
