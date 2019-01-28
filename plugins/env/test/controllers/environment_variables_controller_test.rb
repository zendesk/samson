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
