module Kubernetes
  module HasStatus
    STATUSES = %w[created spinning_up live spinning_down dead failed].freeze

    STATUSES.each do |s|
      define_method("#{s}?") { status == s }
    end
  end

  def status=(new_status)
    super new_status.to_s
  end
end
