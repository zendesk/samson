# frozen_string_literal: true
# rubocop:disable Metrics/LineLength
require_relative '../test_helper'

SingleCov.covered!

describe ApplicationHelper do
  include LocksHelper

  describe "#render_log" do
    it "removes translates ascii escapes to html colors" do
      # false positive ansi codes
      render_log("a[Aa").must_equal "<span class=\"ansible_none\">a[Aa</span>"
      render_log("a[AAa").must_equal "<span class=\"ansible_none\">a[AAa</span>"
      render_log("a[1a").must_equal "<span class=\"ansible_none\">a[1a</span>"
      render_log("a[12a").must_equal "<span class=\"ansible_none\">a[12a</span>"
      render_log("a[12ma").must_equal "<span class=\"ansible_none\">a[12ma</span>"

      # real ansi codes
      render_log("\e[0;32mok").must_equal "<span class=\"ansible_none\"></span><span class=\"ansible_32\">ok</span>"
      render_log("\e[0;33mchanged").must_equal "<span class=\"ansible_none\"></span><span class=\"ansible_33\">changed</span>"
      render_log("\e[0;36mskipping").must_equal "<span class=\"ansible_none\"></span><span class=\"ansible_36\">skipping</span>"
    end

    it "escapes html" do
      result = render_log("<script>1</script>")
      result.must_equal "<span class=\"ansible_none\">&lt;script&gt;1&lt;/script&gt;</span>"
      assert result.html_safe?
    end

    it "converts urls to links" do
      result = render_log("foo http://bar.com bar https://sdf.dd/sdfs/2131/fdfdsf.json baz")
      result.must_equal "<span class=\"ansible_none\">foo " \
        "<a href=\"http://bar.com\">http://bar.com</a> bar " \
        "<a href=\"https://sdf.dd/sdfs/2131/fdfdsf.json\">https://sdf.dd/sdfs/2131/fdfdsf.json</a> baz</span>"
    end
  end

  describe "#markdown" do
    it "converts markdown to html" do
      result = markdown("**hello**")
      result.must_equal "<p><strong>hello</strong></p>\n"
      assert result.html_safe?
    end

    it "does not allow XSS" do
      result = markdown("<script>alert(1)</script>")
      result.must_equal "alert(1)\n"
      assert result.html_safe?
    end
  end

  describe "#controller_action" do
    it "works" do
      stubs(action_name: "foo")
      controller_action.must_equal "test foo"
    end
  end

  describe "#deploy_link" do
    let(:project) { projects(:test) }
    let(:stage) { stages(:test_staging) }
    let(:link) { deploy_link(project, stage) }
    let(:current_user) { users(:admin) }

    it "starts a deploy" do
      assert_includes link, ">Deploy<"
      assert_includes link, %(href="/projects/#{project.to_param}/stages/#{stage.to_param}/deploys/new")
    end

    it "shows locked" do
      Lock.stubs(locked_for?: true)
      assert_includes link, ">Locked<"
    end

    it "shows running deploy" do
      deploy = stage.deploys.create!(
        reference: 'master',
        job: Job.create(user: current_user, command: '', project: project),
        project: project
      )
      stage.stubs(current_deploy: deploy)
      assert_includes link, ">Deploying master...<"
      assert_includes link, %(href="/projects/#{project.to_param}/deploys/#{deploy.id}")
    end

    describe "when stage can run in parallel" do
      before { stage.stubs(:run_in_parallel).returns true }

      it "always starts a deploy" do
        deploy = stage.deploys.create!(
          reference: 'master',
          job: Job.create(user: current_user, command: '', project: project),
          project: project
        )
        stage.stubs(current_deploy: deploy)
        assert_includes link, ">Deploy<"
        assert_includes link, %(href="/projects/#{project.to_param}/stages/#{stage.to_param}/deploys/new")
      end
    end
  end

  describe "#sortable" do
    let(:url_options) { { controller: 'ping', action: 'show' } }

    it "builds a link" do
      sortable("foo").must_equal "<a href=\"/ping?direction=asc&amp;sort=foo\">Foo</a>"
    end

    it "builds a link with given title" do
      sortable("foo", "bar").must_equal "<a href=\"/ping?direction=asc&amp;sort=foo\">bar</a>"
    end

    it "builds a desc link when sorting asc" do
      params[:direction] = "asc"
      params[:sort] = "foo"
      sortable("foo").must_equal "<a href=\"/ping?direction=desc&amp;sort=foo\">Foo</a>"
    end

    it "buils a asc link when sorting asc by a different column" do
      params[:direction] = "asc"
      params[:sort] = "bar"
      sortable("foo").must_equal "<a href=\"/ping?direction=asc&amp;sort=foo\">Foo</a>"
    end
  end

  describe "#github_ok?" do
    let(:status_url) { "#{Rails.application.config.samson.github.status_url}/api/status.json" }

    it "returns cached true" do
      Rails.cache.write(github_status_cache_key, true)
      assert github_ok?
    end

    it "returns cached false" do
      Rails.cache.write(github_status_cache_key, false)
      refute github_ok?
    end

    describe "with an OK response" do
      before do
        stub_request(:get, status_url).to_return(
          headers: { content_type: 'application/json' },
          body: JSON.dump(status: 'good')
        )
      end

      it 'returns ok and caches' do
        assert github_ok?
        Rails.cache.read(github_status_cache_key).must_equal true
      end
    end

    describe "with a bad response" do
      before do
        stub_request(:get, status_url).to_return(
          headers: { content_type: 'application/json' },
          body: JSON.dump(status: 'bad')
        )
      end

      it 'returns false and does not cache' do
        refute github_ok?
        Rails.cache.read(github_status_cache_key).must_equal false
      end
    end

    describe "with an invalid response" do
      before do
        stub_request(:get, status_url).to_return(status: 400)
      end

      it 'returns false and does not cache' do
        refute github_ok?
        Rails.cache.read(github_status_cache_key).must_equal false
      end
    end

    describe "with a timeout" do
      before do
        stub_request(:get, status_url).to_timeout
      end

      it 'returns false caches' do
        refute github_ok?
        Rails.cache.read(github_status_cache_key).must_equal false
      end
    end
  end

  describe "#breadcrumb" do
    let(:stage) { stages(:test_staging) }
    let(:project) { projects(:test) }
    let(:environment) { Environment.find_by_param!('production') }
    let(:deploy_group) { deploy_groups(:pod1) }
    let(:macro) { macros(:test) }
    let(:build) { builds(:docker_build) }

    it "renders strings" do
      breadcrumb("Foobar").must_equal "<ul class=\"breadcrumb\"><li class=\"\"><a href=\"/\">Home</a></li><li class=\"active\">Foobar</li></ul>"
    end

    it "renders empty" do
      breadcrumb.must_equal "<ul class=\"breadcrumb\"><li class=\"active\">Home</li></ul>"
    end

    it "renders stage" do
      breadcrumb(stage).must_equal "<ul class=\"breadcrumb\"><li class=\"\"><a href=\"/\">Home</a></li><li class=\"active\">Staging</li></ul>"
    end

    it "renders locked stage" do
      stage.stubs(lock: Lock.new)
      breadcrumb(stage).must_equal "<ul class=\"breadcrumb\"><li class=\"\"><a href=\"/\">Home</a></li><li class=\"active\"><i class=\"glyphicon glyphicon-lock\"></i> Staging</li></ul>"
    end

    it "renders warning stage" do
      stage.stubs(lock: Lock.new(warning: true))
      breadcrumb(stage).must_equal "<ul class=\"breadcrumb\"><li class=\"\"><a href=\"/\">Home</a></li><li class=\"active\"><i class=\"glyphicon glyphicon-warning-sign\"></i> Staging</li></ul>"
    end

    it "renders project" do
      breadcrumb(project).must_equal "<ul class=\"breadcrumb\"><li class=\"\"><a href=\"/\">Home</a></li><li class=\"active\">Foo</li></ul>"
    end

    it "renders environment" do
      breadcrumb(environment).must_equal "<ul class=\"breadcrumb\"><li class=\"\"><a href=\"/\">Home</a></li><li class=\"active\">Production</li></ul>"
    end

    it "renders deploy_group" do
      breadcrumb(deploy_group).must_equal "<ul class=\"breadcrumb\"><li class=\"\"><a href=\"/\">Home</a></li><li class=\"active\">Pod1</li></ul>"
    end

    it "renders multiple breadcrumbs" do
      breadcrumb(project, stage, "stuff").must_equal "<ul class=\"breadcrumb\"><li class=\"\"><a href=\"/\">Home</a></li><li class=\"\"><a href=\"/projects/foo\">Foo</a></li><li class=\"\"><a href=\"/projects/foo/stages/staging\">Staging</a></li><li class=\"active\">stuff</li></ul>"
    end

    it "refuses to render unknown" do
      assert_raises(RuntimeError) { breadcrumb(111) }
    end

    it "does not allow html injection" do
      stage.name = "<script>alert(1)</script>"
      breadcrumb(stage).must_equal "<ul class=\"breadcrumb\"><li class=\"\"><a href=\"/\">Home</a></li><li class=\"active\">&lt;script&gt;alert(1)&lt;/script&gt;</li></ul>"
    end

    it "renders macro" do
      breadcrumb(macro).must_equal "<ul class=\"breadcrumb\"><li class=\"\"><a href=\"/\">Home</a></li><li class=\"active\">Test Macro</li></ul>"
    end

    it "renders array" do
      breadcrumb(['foo', 'bar'], ['baz', 'bar']).must_equal "<ul class=\"breadcrumb\"><li class=\"\"><a href=\"/\">Home</a></li><li class=\"\"><a href=\"bar\">foo</a></li><li class=\"active\">baz</li></ul>"
    end
  end

  describe "#flash_messages" do
    let(:flash) { {} }

    it "returns empty" do
      flash_messages.must_equal []
    end

    it "returns unknown" do
      flash[:foo] = "bar"
      flash_messages.must_equal [[:foo, :info, "bar"]]
    end

    it "translates bootstrap classes" do
      flash[:notice] = "N"
      flash_messages.must_equal [[:notice, :info, "N"]]
    end

    it "returns arrays of messages" do
      flash[:notice] = ["bar", "baz"]
      flash_messages.must_equal [[:notice, :info, "bar"], [:notice, :info, "baz"]]
    end
  end

  describe "#link_to_delete" do
    it "builds a link" do
      link_to_delete("/foo").must_include ">Delete</a>"
    end

    it "shows common message for paths" do
      link_to_delete("/foo").must_include "Are you sure ?"
    end

    it "shows detailed message for resource" do
      link_to_delete([projects(:test), stages(:test_staging)]).must_include "Delete this Stage ?"
    end

    it "builds a hint for when disabled" do
      link_to_delete("/foo", disabled: "Foo").must_equal(
        "<span title=\"Foo\" class=\"mouseover\">Delete</span>"
      )
    end

    it "adds data/class attribute for remove_container" do
      html = link_to_delete("/foo", remove_container: "tr")
      html.must_include "data-remove-container=\"tr\""
      html.must_include "class=\"remove_container\""
      html.must_include "method"
    end
  end

  describe "#link_to_delete_button" do
    it "builds a button" do
      result = link_to_delete_button("/foo")
      result.must_include "Delete"
      result.must_include "Delete"
    end
  end

  describe "#link_to_url" do
    it "builds a link" do
      link_to_url("b").must_equal "<a href=\"b\">b</a>"
    end
  end

  describe "#environments" do
    it "loads all environments" do
      environments.size.must_equal Environment.all.size
    end

    it "caches" do
      environments.object_id.must_equal environments.object_id
    end
  end

  describe "#render_nested_errors" do
    # simulate what erb will do so we can see html_safe issues
    def render
      ERB::Util.html_escape(render_nested_errors(stage))
    end

    let(:stage) { stages(:test_staging) }

    it "renders nothing for valid" do
      render.must_equal ""
    end

    it "renders simple errors" do
      stage.errors.add(:base, "Kaboom")
      render.must_equal "<ul><li>Kaboom</li></ul>"
    end

    it "renders nested errors" do
      stage.errors.add(:deploy_groups, "Invalid") # happens on save normally .. not a helpful message for our users
      stage.errors.add(:base, "BASE") # other error to make sure nesting is correct
      stage.deploy_groups.to_a.first.errors.add(:base, "Kaboom")
      render.must_equal "<ul><li>Deploy groups Invalid<ul><li>Kaboom</li></ul></li><li>BASE</li></ul>"
    end

    it "does not loop" do
      stage.errors.add(:project, "Invalid")
      stage.project.stubs(stages: [stage])
      stage.project.errors.add(:stages, "Invalid")
      render.must_equal "<ul><li>Project Invalid<ul><li>Stages Invalid</li></ul></li></ul>"
    end

    it "cannot inject html" do
      stage.errors.add(:deploy_groups, "<foo>")
      stage.errors.add(:base, "<bar>")
      stage.deploy_groups.to_a.first.errors.add(:base, "<baz>")
      render.must_equal "<ul><li>Deploy groups &lt;foo&gt;<ul><li>&lt;baz&gt;</li></ul></li><li>&lt;bar&gt;</li></ul>"
    end
  end

  describe "#additional_info" do
    it "builds a help text" do
      additional_info("foo").must_equal "<i class=\"glyphicon glyphicon-info-sign\" title=\"foo\"></i>"
    end
  end

  describe "#link_to_history" do
    let(:user) { users(:admin) }

    with_paper_trail

    it "shows a link" do
      link_to_history(user).must_equal "<a href=\"/versions?item_id=#{user.id}&amp;item_type=User\">History (0)</a>"
    end

    it "shows nothing when new" do
      link_to_history(User.new).must_equal nil
    end

    it "shows number of entries" do
      user.update_attributes!(name: "Foo")
      user.update_attributes!(name: "Bar")
      link_to_history(user).must_include "History (2)"
    end

    it "can not show counter to avoid N+1 queries on large tables" do
      link_to_history(user, counter: false).must_include ">History<"
    end
  end

  describe "#page_title" do
    before { _prepare_context } # setup ActionView::Base

    it "renders content" do
      result = page_title 'xyz'
      result.must_equal "<h1>xyz</h1>"
      content_for(:page_title).must_equal "xyz"
    end

    it "renders html" do
      result = page_title '<img/>'.html_safe
      result.must_equal "<h1><img/></h1>"
      content_for(:page_title).must_equal "<img/>"
    end

    it "renders blocks" do
      result = page_title { "x" }
      result.must_equal "<h1>x</h1>"
      content_for(:page_title).must_equal "x"
    end

    it "renders inside of tabs where we already have a h1" do
      result = page_title "x", in_tab: true
      result.must_equal "<h2>x</h2>"
      content_for(:page_title).must_equal "x"
    end
  end

  describe "#redirect_to_field" do
    let(:root_url) { 'http://foobar.com/' }

    before { stubs(request: stub(referrer: "#{root_url}referrer"), params: {redirect_to: '/params'}) }

    it "stores current parameter" do
      redirect_to_field.must_include "value=\"/params\""
    end

    it "does not store empty parameter" do
      params[:redirect_to] = ""
      redirect_to_field.must_include "value=\"/referrer\""
    end

    describe "without param" do
      before { params.delete(:redirect_to) }

      it "uses referrer when param is missing" do
        redirect_to_field.must_include "value=\"/referrer\""
      end

      it "does not use referrer from other page since redirect_back_or would not work" do
        assert request.stubs(:referrer, request.referrer.sub(root_url, 'http://hacky.com/'))
        redirect_to_field.must_be_nil
      end

      it "is empty when nothing is known" do
        request.stubs(:referrer).returns(nil)
        redirect_to_field.must_be_nil
      end
    end
  end

  describe "#delete_checkbox" do
    it "does not show anything if the object is new" do
      form_for Project.new do |form|
        delete_checkbox(form).must_be_nil
      end
    end

    it "shows a checkbox when the object is persisted" do
      form_for projects(:test) do |form|
        delete_checkbox(form).must_include ">Delete<"
      end
    end
  end
end
