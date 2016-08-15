# frozen_string_literal: true
require_relative '../test_helper'

SingleCov.covered! uncovered: 33

describe DeploysHelper do
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

  describe '#redeploy_button' do
    before do
      @deploy = deploys(:succeeded_test)
      @project = projects(:test)
    end

    describe 'when the deploy already succeeded' do
      it 'generates a link' do
        link = '<a class="btn btn-default" data-toggle="tooltip" data-placement="auto bottom" title="Why? This deploy'\
               ' succeeded." rel="nofollow" data-method="post" href="/projects/foo/stages/staging/deploys?deploy%5Bre'\
               'ference%5D=staging">Redeploy</a>'
        redeploy_button.must_equal link
      end
    end

    describe 'when the deploy is still running' do
      around do |t|
        @deploy.stub(:active?, true) { t.call }
      end

      it 'does not generate a link' do
        redeploy_button.must_equal nil
      end
    end

    describe 'when the deploy failed' do
      around do |t|
        @deploy = deploys(:succeeded_test)
        @deploy.stub(:succeeded?, false) { t.call }
      end

      it 'generates a red link' do
        redeploy_button.must_equal '<a class="btn btn-danger" rel="nofollow" data-method="post" href="/projects/foo/'\
                                   'stages/staging/deploys?deploy%5Breference%5D=staging">Redeploy</a>'
      end
    end
  end
end
