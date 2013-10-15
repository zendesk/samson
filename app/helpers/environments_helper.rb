module EnvironmentsHelper
  def select_valid_environments
    valid_environments.map {|env| [env, env]}
  end

  def valid_environments
    # Eventually consolidate this +
    # JobHistory validation
    # Should be gettable from zendesk_deployment
    %w{master1 master2 staging qa pod1:gamma pod1 pod2:gamma pod2 pod3:gamma pod3}
  end
end
