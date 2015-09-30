require_relative '../../test_helper'

describe SamsonAudit do
  let(:user) { users(:viewer) }
  let(:project) { projects(:test) }
  let(:stage) { stages(:test_staging) }

  setup do
    @object = Object.new
    @object.extend(SamsonAudit)
    @object.stubs(:current_user).returns(user)
  end

  def audit_object(user, action, object, before, after)
    {
      logtype: 'AUDIT',
      logged_at: "#{Time.now.getutc}",
      user: "#{user.name_and_email}",
      object: "#{object.class.name}",
      action: "#{action}",
      before: "#{before}",
      after: "#{after}"
    }
  end

  describe 'given a Webhook object' do
    let(:webhook) { project.webhooks.create!({ branch: 'some branch', stage_id: stage.id, source: 'some source' }) }

    describe 'auditing a create action' do
      let(:action_name) { 'create' }

      setup do
        @object.stubs(:action_name).returns(action_name)
      end

      it('should log the operation using the application logger') do
        Rails.logger.expects(:info).with(JSON.pretty_generate(audit_object(user, action_name, webhook, {}, { id: webhook.id, project_id: project.id, stage_id: stage.id }.to_json)))
        @object.audit(webhook)
      end
    end

    describe 'auditing a destroy action' do
      let(:action_name) { 'destroy' }

      setup do
        @object.stubs(:action_name).returns(action_name)
      end

      it('should log the operation using the application logger') do
        Rails.logger.expects(:info).with(JSON.pretty_generate(audit_object(user, action_name, webhook, { id: webhook.id, project_id: project.id, stage_id: stage.id }.to_json, {})))
        @object.audit(webhook)
      end
    end
  end

  describe 'given a Command object' do
    let(:command) { Command.create({ command: 'some command', project_id: project.id }) }

    describe 'auditing a create action' do
      let(:action_name) { 'create' }

      setup do
        @object.stubs(:action_name).returns(action_name)
      end

      it('should log the operation using the application logger') do
        expected_after = { id: command.id, command: command.command, project_id: project.id, stages: [] }.to_json
        Rails.logger.expects(:info).with(JSON.pretty_generate(audit_object(user, action_name, command, {}, expected_after)))
        @object.audit(command)
      end
    end

    describe 'auditing a destroy action' do
      let(:action_name) { 'destroy' }

      setup do
        @object.stubs(:action_name).returns(action_name)
      end

      it('should log the operation using the application logger') do
        expected_before = { id: command.id, command: command.command, project_id: project.id, stages: [] }.to_json
        Rails.logger.expects(:info).with(JSON.pretty_generate(audit_object(user, action_name, command, expected_before, {})))
        @object.audit(command)
      end
    end

    describe 'auditing an update action' do
      let(:action_name) { 'update' }

      setup do
        @object.stubs(:action_name).returns(action_name)
        @object.prepare_audit(command)
        command.update_attributes({ command: 'editted command', project_id: project.id })
      end

      it('should log the operation using the application logger') do
        expected_before = { id: command.id, command: 'some command', project_id: project.id, stages: [] }.to_json
        expected_after = { id: command.id, command: 'editted command', project_id: project.id, stages: [] }.to_json
        Rails.logger.expects(:info).with(JSON.pretty_generate(audit_object(user, action_name, command, expected_before, expected_after)))
        @object.audit(command)
      end
    end
  end

  describe 'given a Stage object' do
    let(:stage) { project.stages.create({ name: 'test' }) }

    describe 'auditing a create action' do
      let(:action_name) { 'create' }

      setup do
        @object.stubs(:action_name).returns(action_name)
      end

      it('should log the operation using the application logger') do
        expected_after = { id: stage.id, name: stage.name, project_id: project.id, commands: [], stage_commands: [] }.to_json
        Rails.logger.expects(:info).with(JSON.pretty_generate(audit_object(user, action_name, stage, {}, expected_after)))
        @object.audit(stage)
      end
    end

    describe 'auditing a destroy action' do
      let(:action_name) { 'destroy' }

      setup do
        @object.stubs(:action_name).returns(action_name)
      end

      it('should log the operation using the application logger') do
        expected_before = { id: stage.id, name: stage.name, project_id: project.id, commands: [], stage_commands: [] }.to_json
        Rails.logger.expects(:info).with(JSON.pretty_generate(audit_object(user, action_name, stage, expected_before, {})))
        @object.audit(stage)
      end
    end

    describe 'auditing an update action' do
      let(:action_name) { 'update' }

      setup do
        @object.stubs(:action_name).returns(action_name)
        @object.prepare_audit(stage)

        stage.update_attributes({ command: 'stage command' })
      end

      it('should log the operation using the application logger') do
        expected_before = { id: stage.id, name: stage.name, project_id: project.id, commands: [], stage_commands: [] }.to_json
        expected_after = { id: stage.id, name: stage.name, project_id: project.id, commands: [], stage_commands: [{ id: stage.stage_commands[0].id, command_id: stage.stage_commands[0].command_id }] }.to_json
        Rails.logger.expects(:info).with(JSON.pretty_generate(audit_object(user, action_name, stage, expected_before, expected_after)))
        @object.audit(stage)
      end
    end
  end
end

