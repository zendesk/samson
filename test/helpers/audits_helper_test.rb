# frozen_string_literal: true
require_relative '../test_helper'

SingleCov.covered!

describe AuditsHelper do
  include ApplicationHelper

  describe "#readable_ruby_value" do
    it "keeps regular things" do
      readable_ruby_value("Foo").to_s.must_equal '"Foo"'
    end

    it "makes BigDecimal look nice" do
      readable_ruby_value(BigDecimal.new(1.2, 2)).to_s.must_equal '1.2'
    end
  end

  describe "#text_diff" do
    it "produces a safe diff" do
      diff = text_diff("a", "<script>alert(1)</script>")
      diff.must_include "<del>a</del>"
      diff.must_include "<ins><strong>&lt;script&gt;</strong>a<strong>lert(1)&lt;/script&gt;</strong></ins>"
      assert diff.html_safe?
    end
  end

  describe "#audit_author" do
    it "shows regular user" do
      audit_author(Audited::Audit.new(user: users(:admin))).
        must_equal "<a href=\"/users/#{users(:admin).id}\">Admin</a>"
    end

    it "shows user via name" do
      value = audit_author(Audited::Audit.new(username: "Foo"))
      value.must_include "Foo"
      value.must_include "<i"
      assert value.html_safe?
    end

    it "shows deleted user" do
      audit_author(Audited::Audit.new(user_id: 123, user_type: "User")).
        must_equal "User#123"
    end
  end
end
