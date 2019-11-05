# frozen_string_literal: true
require_relative "../test_helper"

SingleCov.covered!

describe EnvironmentVariablesController do
  let!(:env_var) { EnvironmentVariable.create!(name: 'FOO', value: 'bar', parent: projects(:test)) }

  as_a :viewer do
    unauthorized :delete, :destroy, id: 1

    describe "#index" do
      before { EnvironmentVariable.create!(name: 'BAR', value: 'baz', parent: projects(:test)) }

      it "renders" do
        get :index
        assert_response :success
        assigns[:environment_variables].size.must_equal 2
      end

      it "renders json" do
        get :index, format: :json
        assert_response :success
        json_response = JSON.parse response.body
        first_env = json_response['environment_variables'].first
        first_env['name'].must_equal "FOO"
      end

      it "renders json with inlines" do
        get :index, params: {inlines: "parent_name,scope_name"}, format: :json
        assert_response :success
        json_response = JSON.parse response.body
        first_env = json_response['environment_variables'].first
        first_env.keys.must_include "parent_name"
        first_env.keys.must_include "scope_name"
        first_env['parent_name'].must_equal "Foo"
      end

      it "fails with invalid inlines" do
        get :index, params: {inlines: "xyz"}, format: :json
        json_response = JSON.parse response.body
        assert_response :bad_request
        json_response.must_equal(
          "status" => 400,
          "error" => "Forbidden inlines [xyz] found, allowed inlines are [parent_name, scope_name]"
        )
      end

      it "can filter by name" do
        get :index, params: {search: {name: 'FOO'}}
        assert_response :success
        assigns[:environment_variables].size.must_equal 1
      end

      it "can filter by value" do
        get :index, params: {search: {value: 'bar'}}
        assert_response :success
        assigns[:environment_variables].size.must_equal 1
      end

      it "can filter by name and value" do
        get :index, params: {search: {name: 'FOO', value: 'bar'}}
        assert_response :success
        assigns[:environment_variables].size.must_equal 1
      end

      it "can filter by parent_id and parent_type via json" do
        get :index, params: {search: {parent_id: env_var.parent_id, parent_type: env_var.parent_type}}, format: "json"
        assert_response :success
        body = JSON.parse(response.body)
        body["environment_variables"].size.must_equal 2
      end

      it "can filter by scope_id and scope_type via json" do
        env_var.update!(scope_id: 1, scope_type: 'DeployGroup')
        get :index, params: {search: {scope_id: env_var.scope_id, scope_type: env_var.scope_type}}, format: "json"
        assert_response :success
        body = JSON.parse(response.body)
        body["environment_variables"].size.must_equal 1
      end

      it "skips filters without values" do
        get :index, params: {search: {name: '', value: nil}}
        assert_response :success
        assigns[:environment_variables].size.must_equal 2
      end

      it "fails when filtering for unknown" do
        assert_raises ActionController::UnpermittedParameters do
          get :index, params: {search: {group: "xx"}}
        end
      end
    end
  end

  as_a :admin do
    describe "#destroy" do
      it "destroy" do
        assert_difference "EnvironmentVariable.count", -1 do
          delete :destroy, params: {id: env_var.id}
        end
        assert_response :success
      end
    end
  end
end
