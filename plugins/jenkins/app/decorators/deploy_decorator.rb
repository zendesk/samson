# frozen_string_literal: true
Deploy.class_eval do
  has_many :jenkins_jobs, dependent: nil
end
