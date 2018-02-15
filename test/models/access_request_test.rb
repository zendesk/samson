# frozen_string_literal: true

require_relative '../test_helper'

SingleCov.covered!

describe AccessRequest do
  describe 'validations' do
    def access_request(overrides = {})
      attrs = {
        manager_email: 'test@email.com',
        reason: 'many reasons',
        project_ids: [1, 2, 3],
        role_id: 1
      }.merge(overrides)

      AccessRequest.new(attrs)
    end

    it 'is invalid if it is missing a manager email' do
      refute_valid_on access_request(manager_email: nil), :manager_email, "Manager email can't be blank"
    end

    it 'is invalid if it is missing a reason' do
      refute_valid_on access_request(reason: nil), :reason, "Reason can't be blank"
    end

    it 'is invalid if it is missing a project id' do
      refute_valid_on access_request(project_ids: nil), :project_ids, "Project ids can't be blank"
    end

    it 'is invalid if it is missing a role id' do
      refute_valid_on access_request(role_id: nil), :role_id, "Role can't be blank"
    end
  end
end
