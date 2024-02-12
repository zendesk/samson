# frozen_string_literal: true

Deploy.class_eval do
  belongs_to :triggering_deploy, class_name: 'Deploy', optional: true, inverse_of: false
end
