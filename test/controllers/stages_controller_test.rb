# frozen_string_literal: true
require_relative '../test_helper'

SingleCov.covered!

describe StagesController do
  subject { stages(:test_staging) }
  let(:project) { subject.project }

  unauthorized :get, :show, project_id: :foo, id: 1, token: Rails.application.config.samson.badge_token
  unauthorized :get, :index, project_id: :foo, token: Rails.application.config.samson.badge_token, format: :svg

  describe 'GET to :show with svg' do
    let(:valid_params) do
      {
        project_id: subject.project.to_param,
        id: subject.to_param,
        format: :svg,
        token: Rails.application.config.samson.badge_token
      }
    end
    let(:job) { jobs(:succeeded_test) }
    let(:deploy) { deploys(:succeeded_test) }

    it "renders" do
      get :show, params: valid_params
      assert_redirected_to "https://img.shields.io/badge/Staging-staging-green.svg"
    end

    it "fails silently with invalid stage" do
      valid_params[:id] = 'whoops'
      get :show, params: valid_params
      assert_response :not_found
    end

    it "fails silently with invalid token" do
      get :show, params: valid_params.merge(token: 'invalid')
      assert_response :not_found
    end

    it "renders none without deploy" do
      deploy.destroy!
      get :show, params: valid_params
      assert_redirected_to "https://img.shields.io/badge/Staging-None-red.svg"
    end

    it "renders strange characters" do
      subject.update_column(:name, 'Foo & Bar 1-4')
      get :show, params: valid_params
      assert_redirected_to "https://img.shields.io/badge/Foo%20%26%20Bar%201--4-staging-green.svg"
    end
  end

  as_a_viewer do
    unauthorized :get, :index, project_id: :foo
    unauthorized :get, :new, project_id: :foo
    unauthorized :post, :create, project_id: :foo
    unauthorized :get, :edit, project_id: :foo, id: 1
    unauthorized :patch, :update, project_id: :foo, id: 1
    unauthorized :delete, :destroy, project_id: :foo, id: 1
    unauthorized :patch, :reorder, project_id: :foo, id: 1
    unauthorized :get, :clone, project_id: :foo, id: 1

    describe '#show' do
      describe 'valid' do
        before do
          Deploy.delete_all # triggers more github requests
        end

        it 'renders the template' do
          get :show, params: {project_id: subject.project.to_param, id: subject.to_param}
          assert_template :show
        end

        it 'displays a sanitized dashboard' do
          subject.update_attribute :dashboard,
            'START_OF_TEXT<p>PARAGRAPH_TEXT</p><img src="foo.jpg"/>' \
            '<iframe src="http://localhost/foo.txt"></iframe><script>alert("hi there");</script>END_OF_TEXT'

          get :show, params: {project_id: subject.project.to_param, id: subject.to_param}

          response.body.to_s[/START_OF_TEXT.*END_OF_TEXT/].must_equal(
            'START_OF_TEXT<p>PARAGRAPH_TEXT</p><img src="foo.jpg">' \
            '<iframe src="http://localhost/foo.txt"></iframe>alert("hi there");END_OF_TEXT'
          )
        end
      end

      it "fails with invalid project" do
        assert_raises ActiveRecord::RecordNotFound do
          get :show, params: {project_id: 123123, id: subject.to_param}
        end
      end

      it "fails with invalid stage" do
        assert_raises ActiveRecord::RecordNotFound do
          get :show, params: {project_id: subject.project.to_param, id: 123123}
        end
      end
    end
  end

  as_a_project_deployer do
    unauthorized :get, :new, project_id: :foo
    unauthorized :post, :create, project_id: :foo
    unauthorized :get, :edit, project_id: :foo, id: 1
    unauthorized :patch, :update, project_id: :foo, id: 1
    unauthorized :delete, :destroy, project_id: :foo, id: 1
    unauthorized :patch, :reorder, project_id: :foo, id: 1
    unauthorized :get, :clone, project_id: :foo, id: 1

    describe "#index" do
      it "renders html" do
        get :index, params: {project_id: project}
        assert_template 'index'
      end
    end
  end

  as_a_project_admin do
    describe 'GET to #new' do
      describe 'valid' do
        before { get :new, params: {project_id: subject.project.to_param } }

        it 'renders' do
          assert_template :new
        end

        it 'adds global commands by default' do
          assigns(:stage).command_ids.wont_be_empty
        end
      end

      it 'fails for non-existent project' do
        assert_raises ActiveRecord::RecordNotFound do
          get :new, params: {project_id: :foo23123}
        end
      end
    end

    describe 'POST to #create' do
      let(:project) { projects(:test) }

      describe 'valid' do
        subject { assigns(:stage) }

        before do
          new_command = Command.create!(command: 'test2 command')

          post :create, params: {
            project_id: project.to_param,
            stage: {
              name: 'test',
              command: 'test command',
              command_ids: [commands(:echo).id, new_command.id]
            }
          }

          subject.reload
          subject.commands.reload
        end

        it 'is created' do
          subject.persisted?.must_equal(true)
          subject.command_ids.must_include(commands(:echo).id)
          subject.script.must_equal(commands(:echo).command + "\ntest2 command\ntest command")
        end

        it 'redirects' do
          assert_redirected_to project_stage_path(project, assigns(:stage))
        end
      end

      describe 'invalid attributes' do
        before do
          post :create, params: {project_id: project.to_param, stage: {name: nil}}
        end

        it 'renders' do
          assert_template :new
        end
      end

      it "fails with unknown project" do
        assert_raises ActiveRecord::RecordNotFound do
          post :create, params: {project_id: :foo23123}
        end
      end
    end

    describe 'GET to #edit' do
      describe 'valid' do
        before { get :edit, params: {project_id: subject.project.to_param, id: subject.to_param } }

        it 'renders' do
          assert_template :edit

          assert_select '#stage_slack_webhooks_attributes_0_webhook_url'
          assert_select '#stage_slack_webhooks_attributes_0_channel'
        end

        it 'renders with no environments configured' do
          DeployGroup.destroy_all
          Environment.destroy_all
          assert_template :edit
        end
      end

      it 'checks the appropriate next_stage_ids checkbox' do
        next_stage = Stage.create!(name: 'food', project: subject.project)
        subject.next_stage_ids = [next_stage.id]
        subject.save!

        get :edit, params: {project_id: subject.project.to_param, id: subject.to_param }

        checkbox = css_select('#stage_next_stage_ids_').
            detect { |node| node.attribute('value')&.value == next_stage.id.to_s }
        assert_equal 'checked', checkbox.attribute('checked').value
      end

      it "fails with unknown project" do
        assert_raises ActiveRecord::RecordNotFound do
          get :edit, params: {project_id: :foo23123, id: 1}
        end
      end

      it "fails with unknown stage" do
        assert_raises ActiveRecord::RecordNotFound do
          get :edit, params: {project_id: subject.project.to_param, id: 123123}
        end
      end
    end

    describe 'PATCH to #update' do
      describe 'valid id' do
        before do
          patch :update, params: {project_id: subject.project.to_param, id: subject.to_param, stage: attributes}

          subject.reload
        end

        describe 'valid attributes' do
          let(:attributes) do
            {
              command: 'test command',
              name: 'Hello',
              dashboard: '<p>Some text</p>',
              email_committers_on_automated_deploy_failure: true,
              static_emails_on_automated_deploy_failure: "static@example.com"
            }
          end

          it 'updates attributes' do
            subject.name.must_equal('Hello')
            subject.dashboard.must_equal '<p>Some text</p>'
            subject.email_committers_on_automated_deploy_failure?.must_equal true
            subject.static_emails_on_automated_deploy_failure.must_equal "static@example.com"
          end

          it 'redirects' do
            assert_redirected_to project_stage_path(subject.project, subject)
          end

          it 'adds a command' do
            command = subject.commands.reload.last
            command.command.must_equal('test command')
          end
        end

        describe 'invalid attributes' do
          let(:attributes) { { name: nil } }

          it 'renders' do
            assert_template :edit
          end
        end
      end

      it "does not find with invalid project_id" do
        assert_raises ActiveRecord::RecordNotFound do
          patch :update, params: {project_id: :foo23123, id: 1}
        end
      end

      it "does not find with invalid id" do
        assert_raises ActiveRecord::RecordNotFound do
          patch :update, params: {project_id: subject.project.to_param, id: 123123}
        end
      end
    end

    describe 'DELETE to #destroy' do
      describe 'valid' do
        before { delete :destroy, params: {project_id: subject.project.to_param, id: subject.to_param } }

        it 'redirects' do
          assert_redirected_to project_path(subject.project)
        end

        it 'removes stage' do
          subject.reload
          subject.deleted_at.wont_be_nil
        end
      end

      it "fails with invalid project" do
        assert_raises ActiveRecord::RecordNotFound do
          delete :destroy, params: {project_id: :foo23123, id: 1}
        end
      end

      it "fails with invalid stage" do
        assert_raises ActiveRecord::RecordNotFound do
          delete :destroy, params: {project_id: subject.project.to_param, id: 123123}
        end
      end
    end

    describe 'GET to #clone' do
      before { get :clone, params: {project_id: subject.project.to_param, id: subject.to_param } }

      it 'renders :new' do
        assert_template :new
      end
    end

    describe 'PATCH to #reorder' do
      before { patch :reorder, params: {project_id: subject.project.to_param, stage_id: [subject.id] } }

      it 'succeeds' do
        assert_response :success
      end
    end
  end
end
