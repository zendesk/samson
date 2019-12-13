# frozen_string_literal: true
require_relative '../test_helper'

SingleCov.covered!

describe StagesController do
  subject { stages(:test_staging) }
  let(:project) { subject.project }
  let(:json) { JSON.parse(response.body) }

  unauthorized :get, :show, project_id: :foo, id: 1, token: Rails.application.config.samson.badge_token
  unauthorized :get, :index, project_id: :foo, token: Rails.application.config.samson.badge_token, format: :svg

  def stage_no_code_deployed_disabled
    get :new, params: {project_id: subject.project.to_param}
    assert_select "#stage_no_code_deployed" do |input|
      return input.attr("disabled").present?
    end
  end

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

    it "fails silently without token" do
      get :show, params: valid_params.except(:token)
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

  as_a :viewer do
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

        it 'renders json' do
          get :show, params: {project_id: subject.project.to_param, id: subject.to_param}, format: :json
          assert_response :success
          json.keys.must_equal ['stage']
          json['stage'].keys.must_include 'name'
        end

        it 'renders kubernetes stages if k8s stage' do
          subject.update_attribute :kubernetes, true
          get :show, params: {
            project_id: subject.project.to_param, id: subject.to_param,
            include: "kubernetes_matrix"
          }, format: :json
          assert_response :success
          json.keys.must_equal ['stage']
          json["stage"].keys.must_include 'kubernetes_matrix'
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

        it 'renders deploys mentioned in the include param' do
          get :show, params: {
            project_id: subject.project.to_param, id: subject.to_param,
            includes: "last_deploy,last_succeeded_deploy,active_deploy"
          }, format: :json
          assert_response :success
          json.keys.must_equal ["stage", "last_deploys", "last_succeeded_deploys", "active_deploys"]
          json["stage"].keys.must_include 'last_deploy_id'
          json["stage"].keys.must_include 'last_succeeded_deploy_id'
          json["stage"].keys.must_include 'active_deploy_id'
        end

        it 'renders deploy_groups if included in the includes param' do
          get :show, params: {
            project_id: subject.project.to_param, id: subject.to_param,
            includes: "deploy_groups"
          }, format: :json

          assert_equal subject.deploy_group_ids, json['stage']['deploy_group_ids']
          json.keys.must_include 'deploy_groups'
          json['deploy_groups'].first.keys.must_include 'id'
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

    describe "#index" do
      it "renders html" do
        get :index, params: {project_id: project}
        assert_template 'index'
      end

      it "renders html without pagination" do
        stages = project.stages
        get :index, params: {project_id: project, per_page: 1}
        assigns(:stages).count.must_equal stages.count
      end

      it "renders json" do
        get :index, params: {project_id: project}, format: :json
        assert_response :success
        json.keys.must_equal ['stages']
        json['stages'][0].keys.must_include 'name'
      end

      it "render json with pagination" do
        get :index, params: {project_id: project, per_page: 1}, format: :json
        assigns(:stages).count.must_equal 1
      end
    end
  end

  as_a :project_deployer do
    unauthorized :get, :new, project_id: :foo
    unauthorized :post, :create, project_id: :foo
    unauthorized :get, :edit, project_id: :foo, id: 1
    unauthorized :patch, :update, project_id: :foo, id: 1
    unauthorized :delete, :destroy, project_id: :foo, id: 1
    unauthorized :patch, :reorder, project_id: :foo, id: 1
    unauthorized :get, :clone, project_id: :foo, id: 1
    unauthorized :post, :clone, project_id: :foo, id: 1
  end

  as_a :project_admin do
    describe '#new' do
      describe 'valid' do
        before { get :new, params: {project_id: subject.project.to_param} }

        it 'renders' do
          assert_template :new
        end

        it 'adds no commands by default' do
          assigns(:stage).command_ids.must_equal []
        end

        it 'disabled to alter `does not deploy code`' do
          assert stage_no_code_deployed_disabled
        end
      end

      it 'fails for non-existent project' do
        assert_raises ActiveRecord::RecordNotFound do
          get :new, params: {project_id: :foo23123}
        end
      end
    end

    describe '#create' do
      def create_stage(overrides = {})
        params = {project_id: project.to_param}.merge(overrides)

        post :create, params: params

        subject.reload
      end

      let(:project) { projects(:test) }

      it 'is creates' do
        create_stage(stage: {name: 'test', command_ids: [commands(:echo).id, "one more"]})

        stage = assigns(:stage)
        stage.script.must_equal "echo hello\none more"
        stage.commands.last.project.must_equal project
        assert_redirected_to project_stage_path(project, stage)
      end

      it 'fails when invalid' do
        create_stage(stage: {name: nil, command_ids: ['echo foobar']})
        assert_template :new
      end

      it "fails when trying to set no code deployed" do
        assert_raises ActionController::UnpermittedParameters do
          create_stage(stage: {name: "test", no_code_deployed: true})
        end
      end

      it "fails with unknown project" do
        assert_raises ActiveRecord::RecordNotFound do
          post :create, params: {project_id: :foo23123}
        end
      end
    end

    describe '#edit' do
      describe 'valid' do
        before { get :edit, params: {project_id: subject.project.to_param, id: subject.to_param} }

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

      describe "moving projects" do
        let(:echo_command) { commands(:echo) }
        before do
          other_project = project.dup
          other_project.update(name: 'duplicate', permalink: 'duplicate')

          echo_command.project_id = other_project.id
          echo_command.save!
        end

        it 'has no_access css class for commands when no admin for both' do
          get :edit, params: {project_id: subject.project.to_param, id: subject.to_param}
          assert_select '.no_access', echo_command.command
        end
      end

      it 'checks the appropriate next_stage_ids checkbox' do
        next_stage = Stage.create!(name: 'food', project: subject.project)
        subject.next_stage_ids = [next_stage.id]
        subject.save!

        get :edit, params: {project_id: subject.project.to_param, id: subject.to_param}
        checkbox = css_select("#stage_next_stage_ids_#{next_stage.id}")
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

    describe '#update' do
      describe 'valid id' do
        before do
          patch :update, params: {project_id: subject.project.to_param, id: subject.to_param, stage: attributes}

          subject.reload
        end

        describe 'valid attributes' do
          let(:attributes) do
            {
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
        end

        describe 'invalid attributes' do
          let(:attributes) { {name: nil} }

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

    describe '#destroy' do
      describe 'valid' do
        before { delete :destroy, params: {project_id: subject.project.to_param, id: subject.to_param} }

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

    describe '#clone' do
      def clone(method, format, extra = {})
        send(
          method,
          :clone,
          params: {project_id: subject.project.to_param, id: subject.to_param}.merge(extra),
          format: format
        )
      end

      it 'renders' do
        clone :get, :html
        assert_template :new
      end

      it 'creates for json and modifies' do
        clone :post, :json, stage: {name: 'Foo'}
        assert_response :success
        json.keys.must_equal ['stage']
        json['stage']['name'].must_equal 'Foo'
      end
    end

    describe '#reorder' do
      before { patch :reorder, params: {project_id: subject.project.to_param, stage_id: [subject.id]} }

      it 'succeeds' do
        assert_response :success
      end
    end
  end

  as_a :admin do
    describe '#new' do
      it 'can alter `does not deploy code`' do
        refute stage_no_code_deployed_disabled
      end
    end

    describe '#create' do
      subject { assigns(:stage) }
      it 'permits `no_code_deployed` in params' do
        params = {project_id: projects(:test).to_param, stage: {name: 'test', no_code_deployed: true}}
        post :create, params: params
        subject.reload
        assert subject.no_code_deployed
      end
    end
  end
end
