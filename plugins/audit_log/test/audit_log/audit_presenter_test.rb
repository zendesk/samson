# frozen_string_literal: true
require_relative '../test_helper'

SingleCov.covered! unless defined?(Rake) # rake preloads all plugins

describe 'SamsonAuditLog::AuditPresenter' do
  describe '.present' do
    it 'returns filtered deploy' do
      deploy = Deploy.first
      presenter_filter_test(deploy, SamsonAuditLog::DeployPresenter.present(deploy))
    end

    it 'returns filtered deploy group' do
      deploy_group = DeployGroup.first
      presenter_filter_test(deploy_group, SamsonAuditLog::DeployGroupPresenter.present(deploy_group))
    end

    it 'returns filtered project' do
      project = Project.first
      presenter_filter_test(project, SamsonAuditLog::ProjectPresenter.present(project))
    end

    it 'returns filtered stage' do
      stage = Stage.first
      presenter_filter_test(stage, SamsonAuditLog::StagePresenter.present(stage))
    end

    it 'returns filtered user' do
      user = User.first
      presenter_filter_test(user, SamsonAuditLog::UserPresenter.present(user))
    end

    it 'returns filtered user project role' do
      user_project_role = UserProjectRole.first
      presenter_filter_test(user_project_role, SamsonAuditLog::UserProjectRolePresenter.present(user_project_role))
    end

    it 'returns unfiltered models with no presenter' do
      environment = Environment.first
      presenter_filter_test(environment, environment)
    end

    it 'returns arrays unmodified' do
      test = ['foo', 'bar']
      presenter_filter_test(test, test)
    end

    it 'returns object unmodified' do
      test = {foo: 'bar'}
      presenter_filter_test(test, test)
    end

    it 'returns nil for nil passed' do
      presenter_filter_test(nil, nil)
    end

    def presenter_filter_test(input, expected)
      filtered = SamsonAuditLog::AuditPresenter.present(input)
      filtered.must_equal expected
    end
  end
end
