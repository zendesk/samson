# frozen_string_literal: true
require_relative '../test_helper'

SingleCov.covered!

describe SecretsHelper do
  describe "#render_secret_attribute" do
    it "renders simple" do
      render_secret_attribute(:foo, "Bar").must_equal "Bar"
    end

    it "renders known user" do
      render_secret_attribute(:creator_id, users(:admin).id).must_include "Admin"
    end

    it "renders deleted user" do
      render_secret_attribute(:creator_id, 123).must_equal "Unknown user 123"
    end

    it "caches know users" do
      admin = users(:admin)
      deployer = users(:deployer)
      assert_sql_queries 2 do
        2.times do
          render_secret_attribute(:creator_id, admin.id).must_include "Admin"
          render_secret_attribute(:creator_id, deployer.id).must_include "Deployer"
        end
      end
    end

    it "caches unknown users" do
      assert_sql_queries 1 do
        2.times { render_secret_attribute(:creator_id, 123) }
      end
    end
  end
end
