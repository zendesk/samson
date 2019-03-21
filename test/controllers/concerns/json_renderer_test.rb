# frozen_string_literal: true
require_relative '../../test_helper'

SingleCov.covered!

describe "JsonRenderer Integration" do
  describe "#render_json_with_includes" do
    let(:user) { users(:admin) }
    let(:json) { JSON.parse(@response.body) }

    before { stub_session_auth }

    it "renders without includes" do
      get '/deploys.json'
      assert_response :success
      json.keys.must_equal ['deploys']
      json['deploys'].first.keys.must_include "job_id"
      json['deploys'].first.keys.wont_include "job_ids"
      json['deploys'].first.keys.wont_include "job"
    end

    it "renders single without includes" do
      get "/projects/#{projects(:test).to_param}/deploys/#{deploys(:succeeded_test).id}.json"
      assert_response :success
      json.keys.must_equal ['deploy']
      json['deploy'].keys.must_include "job_id"
    end

    it "renders single includes" do
      get '/deploys.json', params: {includes: "job"}
      assert_response :success
      json.keys.must_equal ['deploys', 'jobs']
      json['deploys'].first.keys.must_include "job_id"
      json['deploys'].first.keys.wont_include "job_ids"
      json['deploys'].first.keys.wont_include "job"
      json['jobs'].first.keys.must_include "id"
    end

    it "renders multiple includes" do
      get '/deploys.json', params: {includes: "job,project"}
      assert_response :success
      json.keys.must_equal ['deploys', 'jobs', 'projects']
    end

    it "renders plural includes with _ids" do
      get '/users.json', params: {includes: "user_project_roles"}
      assert_response :success
      json.keys.must_equal ['users', 'user_project_roles']
      json['users'].first.keys.must_include 'user_project_role_ids'
      ids = json['user_project_roles'].map { |upr| upr['id'] }
      ids.size.must_equal ids.uniq.size
    end

    it "renders has_one with id" do
      get '/deploy_groups.json', params: {includes: 'kubernetes_cluster'}
      json.keys.must_equal ['deploy_groups', 'kubernetes_clusters']
      json['deploy_groups'].first.keys.must_include "kubernetes_cluster_id"
    end

    it "can add custom things via yield" do
      project = projects(:test)
      stage = stages(:test_staging)
      get "/projects/#{project.to_param}/stages/#{stage.to_param}.json?include=kubernetes_matrix"
      json.keys.must_equal ['stage']
      assert json['stage'].key?('kubernetes_matrix')
    end

    it "shows a descriptive error to users that use unsupported includes" do
      get '/deploys.json', params: {includes: "nope"}
      assert_response :bad_request
      json.must_equal(
        "status" => 400,
        "error" => "Forbidden includes [nope] found, allowed includes are [job, project, user, stage]"
      )
    end

    describe '.allowed_inlines' do
      before do
        EnvironmentVariable.create!(name: 'FOO', value: 'bar', parent: projects(:test))
      end

      it "renders single inlines" do
        get '/environment_variables.json', params: {inlines: "parent_name"}
        assert_response :success
        json.keys.must_equal ['environment_variables']
        json['environment_variables'].first.keys.must_include "parent_name"
        json['environment_variables'].first.keys.wont_include "scope_name"
      end

      it "renders multiple inlines" do
        get '/environment_variables.json', params: {inlines: "parent_name,scope_name"}
        assert_response :success
        json.keys.must_equal ['environment_variables']
        json['environment_variables'].first.keys.must_include "parent_name"
        json['environment_variables'].first.keys.must_include "scope_name"
      end

      it "skips inlines with empty collection" do
        get '/environment_variables.json', params: {inlines: "parent_name", search: {name: 'xyz'}}
        assert_response :success
        json['environment_variables'].must_be_empty
      end
    end
  end
end
