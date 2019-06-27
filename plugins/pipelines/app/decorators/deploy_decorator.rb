# frozen_string_literal: true

Deploy.class_eval do
  belongs_to :triggering_deploy,
    class_name: 'Deploy', foreign_key: 'triggering_deploy_id', optional: true, inverse_of: nil
end
