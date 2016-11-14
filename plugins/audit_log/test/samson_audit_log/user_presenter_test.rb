# frozen_string_literal: true
require_relative '../test_helper'

SingleCov.covered!

describe 'SamsonAuditLog::UserPresenter' do
  let(:user) { User.first }

  describe '.present' do
    it 'returns filtered object' do
      object = SamsonAuditLog::UserPresenter.present(user)
      object.keys.must_equal [:id, :email, :name, :role, :created_at, :updated_at]
      object[:role].keys.must_equal [:id, :name]
    end
  end
end
