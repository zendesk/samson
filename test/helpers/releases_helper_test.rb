# frozen_string_literal: true
require_relative '../test_helper'

SingleCov.covered!

describe ReleasesHelper do
  describe "#release_label" do
    let(:release) { releases(:test) }
    let(:result) { release_label(projects(:test), release) }

    it "produces a label" do
      result.must_equal "<a class=\"release-label label label-success\" href=\"/projects/foo/releases/v123\">v123</a>"
    end
  end

  describe "#link_to_deploy_stage" do
    let(:stage) { stages(:test_staging) }
    let(:release) { Release.new }
    before { @project = stage.project } # ugly ...

    it "links to a new deploy when it needs to be confirmed" do
      stage.confirm = true
      link_to_deploy_stage(stage, release).must_include "/projects/foo/stages/staging/deploys/new?"
    end

    it "links creating a deploy when it does not needs to be confirmed" do
      link_to_deploy_stage(stage, release).must_include "/projects/foo/stages/staging/deploys?"
    end
  end
end
