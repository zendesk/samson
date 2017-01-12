# frozen_string_literal: true
require_relative '../test_helper'

SingleCov.covered! uncovered: 8

describe DeploysHelper do
  include StatusHelper

  let(:deploy) { deploys(:succeeded_test) }

  describe "#deploy_output" do
    let(:output) { 'This worked!' }

    before do
      @deploy = deploy
      @project = deploy.project
      ActionView::Base.any_instance.stubs(current_user: users(:deployer))
    end

    it "renders output when deploy is finished" do
      deploy_output.must_include output
    end

    describe "pending job" do
      let(:result) { deploy_output }

      before { deploy.job.status = 'pending' }

      it "renders restart warning when deploy is waiting for restart" do
        result.wont_include output
        result.must_include 'Samson has restarted'
      end

      it "renders queued warning when job is waiting to be executed" do
        with_job_execution do
          result.wont_include output
          result.must_include 'previous deploys have finished'
        end
      end

      it "renders buddy check when waiting for buddy" do
        deploy.expects(:waiting_for_buddy?).returns(true)
        result.wont_include output
        result.must_include 'This deploy requires a buddy.'
      end
    end
  end

  describe "#deploy_page_title" do
    it "renders" do
      @deploy = deploy
      @project = projects(:test)
      deploy_page_title.must_equal "Staging deploy (succeeded) - Project"
    end
  end

  describe "#deploy_notification" do
    it "renders a notification" do
      @project = projects(:test)
      @deploy = deploy
      deploy_notification.must_equal "Samson deploy finished:\nProject / Staging succeeded"
    end
  end

  describe '#syntax_highlight' do
    it "renders code" do
      syntax_highlight("puts 1").must_equal "puts <span class=\"integer\">1</span>"
    end
  end

  describe "#file_status_label" do
    it "shows added" do
      file_status_label('added').must_equal "<span class=\"label label-success\">A</span>"
    end

    it "shows removed" do
      file_status_label('removed').must_equal "<span class=\"label label-danger\">R</span>"
    end

    it "shows modified" do
      file_status_label('modified').must_equal "<span class=\"label label-info\">M</span>"
    end

    it "shows changed" do
      file_status_label('changed').must_equal "<span class=\"label label-info\">C</span>"
    end

    it "shows renamed" do
      file_status_label('renamed').must_equal "<span class=\"label label-info\">R</span>"
    end

    it "fails on unknown" do
      assert_raises(KeyError) { file_status_label('wut') }
    end
  end

  describe "#file_changes_label" do
    it "renders new label" do
      file_changes_label(1, "foo").must_equal "<span class=\"label foo\">1</span>"
    end

    it "does not render new label when count is zero" do
      file_changes_label(0, "bar").must_equal nil
    end
  end

  describe "#github_users" do
    it "renders users' avatar" do
      result = github_users(
        [
          stub(url: 'foourl', login: 'foologin', avatar_url: 'fooavatar'),
          stub(url: 'barurl', login: 'bar"<script>login', avatar_url: 'baravatar'),
        ]
      )
      result.must_equal(
        "<a title=\"foologin\" href=\"foourl\">" \
          "<img width=\"20\" height=\"20\" src=\"/images/fooavatar\" alt=\"Fooavatar\" />" \
        "</a> " \
        "<a title=\"bar&quot;&lt;script&gt;login\" href=\"barurl\">" \
          "<img width=\"20\" height=\"20\" src=\"/images/baravatar\" alt=\"Baravatar\" />" \
        "</a>"
      )
      result.html_safe?.must_equal true
    end

    it "ignores nils" do
      github_users([nil, nil]).must_equal " "
    end
  end

  describe "#redeploy_button" do
    let(:redeploy_warning) { "Why? This deploy succeeded." }

    before do
      @deploy = deploy
      @project = projects(:test)
    end

    it "generates a link" do
      link = redeploy_button
      link.must_include redeploy_warning # warns about redeploying
      link.must_include "?deploy%5Bkubernetes_reuse_build%5D=false" \
        "&amp;deploy%5Bkubernetes_rollback%5D=true&amp;deploy%5Breference%5D=staging\"" # copies params
      link.must_include "Redeploy"
    end

    it 'does not generate a link when deploy is active' do
      deploy.job.stubs(active?: true)
      redeploy_button.must_be_nil
    end

    it "generates a red link when deply failed" do
      deploy.stubs(succeeded?: false)
      redeploy_button.must_include "btn-danger"
      redeploy_button.wont_include redeploy_warning
    end
  end

  describe "#stop_button" do
    before { stubs(request: stub(fullpath: '/hello')) }

    it "builds with a deploy" do
      button = stop_button(deploy: deploy, project: deploy.project)
      button.must_include ">Stop<"
      button.must_include "?redirect_to=%2Fhello\""
    end

    it "builds with a job" do
      button = stop_button(deploy: deploy.job, project: deploy.project)
      button.must_include ">Stop<"
    end
  end
end
