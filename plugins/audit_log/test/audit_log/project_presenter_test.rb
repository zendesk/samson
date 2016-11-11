# frozen_string_literal: true
require_relative '../test_helper'

SingleCov.covered! unless defined?(Rake) # rake preloads all plugins

describe 'SamsonAuditLog::ProjectPresenter' do
  let(:project) { Project.first }

  describe '.present' do
    it 'returns filtered object' do
      object = SamsonAuditLog::ProjectPresenter.present(project)
      object.keys.must_equal [:id, :permalink, :name, :created_at, :updated_at]
    end
  end
end
