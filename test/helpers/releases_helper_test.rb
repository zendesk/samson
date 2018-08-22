# frozen_string_literal: true
require_relative '../test_helper'

SingleCov.covered!

describe ReleasesHelper do
  describe "#release_label" do
    let(:release) { releases(:test) }
    let(:result) { release_label(projects(:test), release) }

    it "produces a label" do
      result.must_equal(
        "<a class=\"release-label label label-success\" data-ref=\"v123\" href=\"/projects/foo/releases/v123\">v123</a>"
      )
    end
  end

  describe "#status_glyphicon" do
    include ApplicationHelper

    it "renders an icon for success" do
      status_glyphicon("success").must_equal %(<i class="glyphicon glyphicon-ok text-success" data-toggle="tooltip" data-placement="right" title="Github status: success"></i>)
    end

    it "renders an icon for failure" do
      status_glyphicon("failure").must_equal %(<i class="glyphicon glyphicon-remove text-danger" data-toggle="tooltip" data-placement="right" title="Github status: failure"></i>)
    end

    it "renders an icon for missing status" do
      status_glyphicon("missing").must_equal %(<i class="glyphicon glyphicon-minus text-muted" data-toggle="tooltip" data-placement="right" title="Github status: missing"></i>)
    end

    it "renders an icon for pending status" do
      status_glyphicon("pending").must_equal %(<i class="glyphicon glyphicon-hourglass text-primary" data-toggle="tooltip" data-placement="right" title="Github status: pending"></i>)
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
