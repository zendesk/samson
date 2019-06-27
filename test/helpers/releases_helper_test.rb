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

  describe "#commit_status_icon" do
    include ApplicationHelper

    it "renders an icon for success" do
      html = commit_status_icon("success")
      html.must_include "glyphicon-ok"
      html.must_include "text-success"
      html.must_include "Commit status: success"
    end

    it "renders an icon for failure" do
      html = commit_status_icon("failure")
      html.must_include "glyphicon-remove"
      html.must_include "text-danger"
      html.must_include "Commit status: failure"
    end

    it "renders an icon for missing status" do
      html = commit_status_icon("missing")
      html.must_include "glyphicon-minus"
      html.must_include "text-muted"
      html.must_include "Commit status: missing"
    end

    it "renders an icon for pending status" do
      html = commit_status_icon("pending")
      html.must_include "glyphicon-hourglass"
      html.must_include "text-primary"
      html.must_include "Commit status: pending"
    end

    it "renders an icon for error status" do
      html = commit_status_icon("error")
      html.must_include "glyphicon-exclamation-sign"
      html.must_include "text-warning"
      html.must_include "Commit status: error"
    end

    it "assumes 'error' for 1-off states produced by release status" do
      html = commit_status_icon("key_not_found")
      html.must_include "glyphicon-exclamation-sign"
      html.must_include "text-warning"
      html.must_include "Commit status: key_not_found"
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
