# frozen_string_literal: true
require_relative "../../test_helper"

SingleCov.covered!

describe Samson::RepoProviderStatus do
  describe ".errors" do
    it "shows error when periodical is not running" do
      Samson::RepoProviderStatus.errors.first.must_include "PERIODICAL"
    end

    it "is empty when everything is fine" do
      Samson::Hooks.with_callback(:repo_provider_status) do
        Samson::RepoProviderStatus.refresh
      end
      Samson::RepoProviderStatus.errors.must_equal []
    end

    it "can show multiple errors" do
      Samson::Hooks.with_callback(:repo_provider_status, -> { "Foo" }, -> { nil }, -> { "Bar" }) do
        Samson::RepoProviderStatus.refresh
      end
      Samson::RepoProviderStatus.errors.must_equal ["Foo", "Bar"]
    end
  end
end
